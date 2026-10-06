/**
 * Unit test for OppSplitEngine.
 * Focuses on business logic for T1, T2, and T3 split creation and management.
 */
@IsTest
private class OppSplitEngineTest {

    @TestSetup
    static void makeData() {
        TestDataFactory.setAutomation(true);

        User oppOwner = TestDataFactory.createTestUser('engine.oppowner@test.invalid', 'EngineOppOwner', 'eoo');
        User accOwner = TestDataFactory.createTestUser('engine.accowner@test.invalid', 'EngineAccOwner', 'eao');
        insert new List<User>{ oppOwner, accOwner };

        // Use a generic SObject to avoid the "Cannot resolve symbol Id" compiler issue on the User type
        SObject accOwnerObj = accOwner;
        Account acc = TestDataFactory.getAccount('EngineTestAccount', (Id)accOwnerObj.get('Id'), Date.newInstance(2025, 1, 1));
        insert acc;
    }

    private static Id getSplitTypeId(String label) {
        List<OpportunitySplitType> types = [SELECT Id FROM OpportunitySplitType WHERE MasterLabel = :label LIMIT 1];
        return types.isEmpty() ? null : types[0].Id;
    }

    private static Id getUserId(String lastName) {
        SObject u = [SELECT Id FROM User WHERE LastName = :lastName LIMIT 1];
        return (Id)u.get('Id');
    }

    private static Account getAccount() {
        return [SELECT Id, OwnerId FROM Account WHERE Name = 'EngineTestAccount' LIMIT 1];
    }

    private static Opportunity buildOpp(Id accId, Id ownerId) {
        return TestDataFactory.getOpp(accId, ownerId, Date.newInstance(2026, 12, 31), 'Explore', null, 'EngineOpp');
    }

    private static void setAutomation(Boolean enabled) {
        TestDataFactory.setAutomation(enabled);
        OppSplitService.clearAutomationSettingsCache();
    }

    /**
     * Verifies that execute() handles inserts and creates splits for both owners across all tiers.
     */
    @IsTest
    static void execute_onInsert_createsAllSplits() {
        Account acc = getAccount();
        Id ownerId = getUserId('EngineOppOwner');

        // We must insert the opp with automation OFF so we have an Id to work with in the Engine
        setAutomation(false);

        Opportunity opp = buildOpp(acc.Id, ownerId);
        opp.StageName = 'Explore';
        opp.Net_Revenue_Forecast__c = 1000;
        opp.Estimate_Managed_Service_Revenue__c = 500;
        opp.Total_Amount_T3__c = 200;
        insert opp;

        // Re-query to get formula fields (e.g. Quota_Update_Allowed__c) populated from DB
        Opportunity insertedOpp = [
            SELECT Id, OwnerId, AccountId, CloseDate, Amount, Net_Revenue_Forecast__c,
                   Estimate_Licensing_Revenue__c, Estimate_Managed_Service_Revenue__c,
                   T1_Opp__c, Total_Amount_T2__c, Total_Amount_T3__c, T3_From_Products__c,
                   Quota_Update_Allowed__c, Run_Splits_Flow__c, IsClosed
            FROM Opportunity WHERE Id = :opp.Id
        ];

        // Re-enable automation for the engine execution
        setAutomation(true);

        Test.startTest();
        OppSplitEngine.execute(new List<Opportunity>{ insertedOpp }, null);
        Test.stopTest();

        List<OpportunitySplit> splits = [SELECT Id, SplitTypeId, SplitOwnerId FROM OpportunitySplit WHERE OpportunityId = :insertedOpp.Id];
        System.assert(splits.size() >= 3, 'Should have created at least one split per tier. Found: ' + splits.size());
    }

    /**
     * Verifies admin repair logic (Run_Splits_Flow__c).
     */
    @IsTest
    static void execute_adminRepair_createsMissingSplits() {
        Account acc = getAccount();
        Id ownerId = getUserId('EngineOppOwner');
        Id t1TypeId = getSplitTypeId('T1');

        setAutomation(false);

        Opportunity opp = buildOpp(acc.Id, ownerId);
        opp.T1_Opp__c = 'Yes';
        opp.Net_Revenue_Forecast__c = 1000;
        opp.StageName = 'Explore';
        insert opp;

        // Manually delete only the T1 splits we expect to recreate,
        // avoiding trying to delete the restricted 100% owner split if it's the standard Revenue type.
        delete [SELECT Id FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitTypeId = :t1TypeId];

        setAutomation(true);

        Opportunity updatedOpp = [SELECT Id, T1_Opp__c, OwnerId, AccountId, CloseDate, Amount, Net_Revenue_Forecast__c, Estimate_Licensing_Revenue__c, Estimate_Managed_Service_Revenue__c, Total_Amount_T2__c, Total_Amount_T3__c, T3_From_Products__c, Run_Splits_Flow__c, Quota_Update_Allowed__c, IsClosed FROM Opportunity WHERE Id = :opp.Id];
        updatedOpp.Run_Splits_Flow__c = true;

        Test.startTest();
        OppSplitEngine.execute(new List<Opportunity>{updatedOpp}, new Map<Id, Opportunity>{opp.Id => opp});
        Test.stopTest();

        System.assertNotEquals(0, [SELECT COUNT() FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitOwnerId = :ownerId AND SplitTypeId = :t1TypeId], 'Should have recreated T1 split');

        Opportunity refreshed = [SELECT Run_Splits_Flow__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(false, refreshed.Run_Splits_Flow__c, 'Repair flag should be reset');
    }

    /**
     * Verifies stale owner deletion logic.
     */
    @IsTest
    static void execute_ownerChange_removesStaleSplits() {
        Account acc = getAccount();
        Id oldOwnerId = getUserId('EngineOppOwner');
        Id newOwnerId = getUserId('EngineAccOwner');

        setAutomation(true);

        Opportunity opp = buildOpp(acc.Id, oldOwnerId);
        opp.StageName = 'Explore';
        opp.Total_Amount_T2__c = 500;
        insert opp;


        Opportunity newOpp = [SELECT Id, OwnerId, AccountId, CloseDate, Amount, Net_Revenue_Forecast__c, Estimate_Licensing_Revenue__c, Estimate_Managed_Service_Revenue__c, T1_Opp__c, Total_Amount_T2__c, Total_Amount_T3__c, T3_From_Products__c, Quota_Update_Allowed__c, Run_Splits_Flow__c, IsClosed FROM Opportunity WHERE Id = :opp.Id];
        newOpp.OwnerId = newOwnerId;

        Test.startTest();
        OppSplitEngine.execute(new List<Opportunity>{newOpp}, new Map<Id, Opportunity>{opp.Id => opp});
        Test.stopTest();

        List<OpportunitySplit> splits = [SELECT Id, SplitOwnerId FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitTypeId = :OppSplitService.getSplitTypeId('T2')];
        for(OpportunitySplit s : splits) {
            System.assertNotEquals(oldOwnerId, s.SplitOwnerId, 'Old owner splits should be deleted');
        }
    }

    /**
     * Regression test for the deletion-pass bug: processDeletions() previously had no
     * IsClosed check, so zeroing a tier amount on an already-closed opportunity would
     * delete the existing split even though the creation pass (correctly) would never
     * recreate it. Verifies the deletion pass now skips closed opportunities entirely.
     */
    @IsTest
    static void execute_closedOpp_amountZeroed_doesNotDeleteSplit() {
        Account acc = getAccount();
        Id ownerId = getUserId('EngineOppOwner');
        Id t2TypeId = getSplitTypeId('T2');

        setAutomation(true);

        Opportunity opp = buildOpp(acc.Id, ownerId);
        opp.Estimate_Managed_Service_Revenue__c = 500;
        opp.Total_Amount_T2__c = 550000;
        insert opp;

        System.assertNotEquals(0,
            [SELECT COUNT() FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitTypeId = :t2TypeId],
            'T2 split should exist before the opportunity is closed.');

        // Close the opportunity via a normal DML update (goes through the trigger).
        update new Opportunity(Id = opp.Id, StageName = 'Closed Won');

        // Re-query the now-closed opportunity with IsClosed populated, to use as the "old" state.
        Opportunity closedOpp = [
            SELECT Id, OwnerId, AccountId, CloseDate, Amount, Net_Revenue_Forecast__c,
                   Estimate_Licensing_Revenue__c, Estimate_Managed_Service_Revenue__c,
                   T1_Opp__c, Total_Amount_T2__c, Total_Amount_T3__c, T3_From_Products__c,
                   Quota_Update_Allowed__c, Run_Splits_Flow__c, IsClosed
            FROM Opportunity WHERE Id = :opp.Id
        ];

        // Simulate the amount rollup zeroing T2 out while the opp is already closed.
        Opportunity zeroedOpp = closedOpp.clone(true, true, true, true);
        zeroedOpp.Total_Amount_T2__c = 0;

        Test.startTest();
        OppSplitEngine.execute(new List<Opportunity>{ zeroedOpp }, new Map<Id, Opportunity>{ opp.Id => closedOpp });
        Test.stopTest();

        System.assertNotEquals(0,
            [SELECT COUNT() FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitTypeId = :t2TypeId],
            'T2 split should NOT be deleted when the amount is zeroed out on an already-closed opportunity.');
    }

    /**
     * Regression test for the T1 race condition: an Opportunity that becomes T1-eligible
     * (CloseDate within the account's T1 window, revenue present) via a rollup that lands
     * AFTER the opportunity already closed would previously stay permanently un-flagged,
     * because the normal creation pass is blocked by isClosed and Run_Splits_Flow__c admin
     * repair only recreates splits when T1_Opp__c is already 'Yes'. Verifies the always-run
     * reconciliation step now catches this case.
     *
     * Quota_Update_Allowed__c is a formula: it stays true on "Closed won - awaiting approval"
     * only when CloseDate is in the current calendar quarter. Tests must match that, not
     * fake the formula field (JSON deserialize drops it).
     */
    @IsTest
    static void execute_closedOppEligibleForT1_reconciliationCreatesSplitAndSetsFlag() {
        Account acc = getAccount();
        Id ownerId = getUserId('EngineOppOwner');
        Id t1TypeId = getSplitTypeId('T1');

        setAutomation(true);

        // CloseDate = today so Quota_Update_Allowed__c remains true after closing
        // (same quarter + year as TODAY, per the formula).
        Opportunity opp = TestDataFactory.getOpp(acc.Id, ownerId, Date.today(), 'Explore', null, 'RaceConditionOpp');
        insert opp;

        System.assertEquals(0,
            [SELECT COUNT() FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitTypeId = :t1TypeId],
            'No T1 split should exist before revenue is set.');

        OppSplitService.resetAutomationFlag();

        // Close + set revenue in the same update. Stage must be one of the closed-won stages
        // the Quota formula actually recognizes (not generic "Closed Won").
        update new Opportunity(
            Id = opp.Id,
            StageName = 'Closed won - awaiting approval',
            Net_Revenue_Forecast__c = 1800
        );

        System.assertNotEquals(0,
            [SELECT COUNT() FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitTypeId = :t1TypeId],
            'T1 split should be created via reconciliation even though the opportunity is already closed.');

        Opportunity refreshed = [SELECT T1_Opp__c, Quota_Update_Allowed__c, IsClosed FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(true, refreshed.IsClosed, 'Precondition: opportunity should be closed.');
        System.assertEquals(true, refreshed.Quota_Update_Allowed__c, 'Precondition: quota updates should still be allowed this quarter.');
        System.assertEquals('Yes', refreshed.T1_Opp__c, 'T1_Opp__c should be set to Yes by the reconciliation step.');
    }

    /**
     * Regression test for the oppsToUpdate map-collision bug: when admin repair
     * (Run_Splits_Flow__c reset) and T1 reconciliation (T1_Opp__c set) both queue a field
     * update for the SAME Opportunity in the SAME trigger invocation, both updates must survive —
     * previously the second Map.put() with a fresh partial Opportunity silently overwrote
     * the first one's field.
     */
    @IsTest
    static void execute_adminRepairAndReconciliationTogether_bothFieldUpdatesPersist() {
        Account acc = getAccount();
        Id ownerId = getUserId('EngineOppOwner');

        setAutomation(true);

        Opportunity opp = TestDataFactory.getOpp(acc.Id, ownerId, Date.today(), 'Explore', null, 'MergeFixOpp');
        insert opp;

        OppSplitService.resetAutomationFlag();

        // Single update: closes the opp AND sets T1-qualifying revenue (triggers reconciliation)
        // AND flips Run_Splits_Flow__c true (triggers admin repair) — all in the same transaction,
        // so both field updates target the same Opportunity Id in the same oppsToUpdate map.
        update new Opportunity(
            Id = opp.Id,
            StageName = 'Closed won - awaiting approval',
            Net_Revenue_Forecast__c = 1800,
            Run_Splits_Flow__c = true
        );

        Opportunity refreshed = [SELECT Run_Splits_Flow__c, T1_Opp__c, Quota_Update_Allowed__c, IsClosed FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(true, refreshed.IsClosed, 'Precondition: opportunity should be closed.');
        System.assertEquals(true, refreshed.Quota_Update_Allowed__c, 'Precondition: quota updates should still be allowed this quarter.');
        System.assertEquals(false, refreshed.Run_Splits_Flow__c,
            'Run_Splits_Flow__c should be reset to false by admin repair.');
        System.assertEquals('Yes', refreshed.T1_Opp__c,
            'T1_Opp__c should still be set to Yes by reconciliation, without being lost to a map overwrite.');
    }
}