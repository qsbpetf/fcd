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
}