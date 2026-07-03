/**
 * End-to-end integration test for the OppSplit automation.
 *
 * All scenarios drive the logic through Opportunity DML and assert on the resulting
 * OpportunitySplit records — no handler methods are called directly.
 *
 * Run this class after every refactoring step to confirm nothing broke.
 *
 * Scenarios covered:
 *   1. Insert with all tier fields → T1 / T2 / T3 splits created for opp owner + acc owner
 *   2. Update T2/T3 amounts to zero → splits for the affected tiers deleted
 *   3. Update T1_Opp__c = 'No' + zero revenue → T1 splits deleted
 *   4. Opp owner changed → old opp owner's splits removed, acc owner splits preserved
 *   5. Account changed → stale (old acc owner's) splits removed
 *   6. Run_Splits_Flow__c checked (admin repair) → missing splits recreated, flag reset
 *   7. Automation disabled → no splits created on insert
 *   8. Run_Splits_Flow__c on a closed opportunity → splits still recreated
 *
 * Infrastructure note:
 *   OppSplitService.tryEnterAutomation() sets a static recursion guard that remains
 *   true for the lifetime of a test method. Call OppSplitService.resetAutomationFlag()
 *   between consecutive DML operations within the same method to reset the guard.
 */
@IsTest
private class OppSplitE2ETest {

    // Test data setup
    @TestSetup
    static void makeData() {
        // Automation disabled so the setup DML does not accidentally trigger split creation.
        TestDataFactory.setAutomation(false);

        SObject oppOwner = TestDataFactory.createTestUser('e2e.oppowner@e2etest.invalid', 'E2EOppOwner', 'e2eoo');
        SObject accOwner = TestDataFactory.createTestUser('e2e.accowner@e2etest.invalid', 'E2EAccOwner', 'e2eao');
        insert new List<SObject>{ oppOwner, accOwner };

        // T1_Start_Date__c = 2025-01-01 so that a CloseDate of 2026-12-31 falls inside the window.
        insert TestDataFactory.getAccount('E2ETestAccount', getUserIdByLastName('E2EAccOwner'), Date.newInstance(2025, 1, 1));
    }

    // Shared helpers
    private static Id getUserIdByLastName(String lastName) {
        SObject userRecord = [SELECT Id FROM User WHERE LastName = :lastName LIMIT 1];
        return (Id) userRecord.get('Id');
    }

    private static Id getOppOwnerId() { return getUserIdByLastName('E2EOppOwner'); }
    private static Id getAccOwnerId()  { return getUserIdByLastName('E2EAccOwner'); }

    private static Account getAccount() {
        return [SELECT Id, OwnerId FROM Account WHERE Name = 'E2ETestAccount' LIMIT 1];
    }

    /** Enables automation and clears the cached settings value so handlers pick it up. */
    private static void enableAutomation() {
        TestDataFactory.setAutomation(true);
        OppSplitService.clearAutomationSettingsCache();
    }

    /**
     * Resets static state between consecutive trigger-firing DML operations within
     * the same test method so that the recursion guard does not carry stale state
     * into the next action.
     */
    private static void resetBetweenActions() {
        OppSplitService.resetAutomationFlag();
    }

    private static Id getSplitTypeId(String label) {
        List<OpportunitySplitType> types = [
            SELECT Id FROM OpportunitySplitType WHERE MasterLabel = :label LIMIT 1
        ];
        return types.isEmpty() ? null : types[0].Id;
    }

    /** Returns a basic Opportunity ready to have tier fields added before insert. */
    private static Opportunity buildOpp(Id accId, Id ownerId) {
        return TestDataFactory.getOpp(
            accId,
            ownerId,
            Date.newInstance(2026, 12, 31), // CloseDate after T1_Start_Date (2025-01-01)
            'Explore',
            null,
            'E2ETestOpp'
        );
    }

    private static Integer countSplits(Id oppId, Id splitTypeId) {
        return [
            SELECT COUNT() FROM OpportunitySplit
            WHERE OpportunityId = :oppId AND SplitTypeId = :splitTypeId
        ];
    }

    private static Integer countSplitsByOwner(Id oppId, Id splitTypeId, Id ownerId) {
        return [
            SELECT COUNT() FROM OpportunitySplit
            WHERE OpportunityId = :oppId AND SplitTypeId = :splitTypeId AND SplitOwnerId = :ownerId
        ];
    }

    // Scenario 1 — Insert creates T1 / T2 / T3 splits for both owners
    @IsTest
    static void insert_withAllTierFields_createsSplitsForBothOwners() {
        Id t1TypeId = getSplitTypeId('T1');
        Id t2TypeId = getSplitTypeId('T2');
        Id t3TypeId = getSplitTypeId('T3');

        Account acc     = getAccount();
        Id oppOwnerId   = getOppOwnerId();
        Id accOwnerId   = getAccOwnerId();

        enableAutomation();

        Opportunity opp = buildOpp(acc.Id, oppOwnerId);

        opp.Net_Revenue_Forecast__c             = 1000;   // qualifies T1 on insert
        opp.Estimate_Managed_Service_Revenue__c = 500;    // qualifies T2 (no-products path)
        opp.Total_Amount_T3__c                  = 200;    // qualifies T3 on insert

        Test.startTest();
        insert opp;
        Test.stopTest();

        // T1 — opp owner and acc owner
        System.assertEquals(1, countSplitsByOwner(opp.Id, t1TypeId, oppOwnerId),
            'T1 split for the opportunity owner should be created on insert.');
        System.assertEquals(1, countSplitsByOwner(opp.Id, t1TypeId, accOwnerId),
            'T1 split for the account owner should be created on insert.');

        // T2 — opp owner and acc owner
        System.assertEquals(1, countSplitsByOwner(opp.Id, t2TypeId, oppOwnerId),
            'T2 split for the opportunity owner should be created on insert.');
        System.assertEquals(1, countSplitsByOwner(opp.Id, t2TypeId, accOwnerId),
            'T2 split for the account owner should be created on insert.');

        // T3 — opp owner and acc owner
        System.assertEquals(1, countSplitsByOwner(opp.Id, t3TypeId, oppOwnerId),
            'T3 split for the opportunity owner should be created on insert.');
        System.assertEquals(1, countSplitsByOwner(opp.Id, t3TypeId, accOwnerId),
            'T3 split for the account owner should be created on insert.');
    }

    // Scenario 2 — T2 and T3 splits deleted when their amounts go to zero
    @IsTest
    static void update_t2AndT3AmountsToZero_deletesSplitsForThoseTiers() {
        Id t2TypeId = getSplitTypeId('T2');
        Id t3TypeId = getSplitTypeId('T3');

        Account acc = getAccount();
        enableAutomation();

        // Insert with T2 and T3 qualifying so splits are created.
        Opportunity opp = buildOpp(acc.Id, getOppOwnerId());

        opp.Estimate_Managed_Service_Revenue__c = 500;
        opp.Total_Amount_T3__c                  = 200;
        insert opp;

        System.assertNotEquals(0, countSplits(opp.Id, t2TypeId),
            'T2 splits should exist before zeroing the amount.');
        System.assertNotEquals(0, countSplits(opp.Id, t3TypeId),
            'T3 splits should exist before zeroing the amount.');

        resetBetweenActions();

        // Zero out both amounts — the delete handler should clean them up.
        opp.Total_Amount_T2__c = 0;
        opp.Total_Amount_T3__c = 0;

        Test.startTest();
        update opp;
        Test.stopTest();

        System.assertEquals(0, countSplits(opp.Id, t2TypeId),
            'All T2 splits should be deleted when Total_Amount_T2__c is set to zero.');
        System.assertEquals(0, countSplits(opp.Id, t3TypeId),
            'All T3 splits should be deleted when Total_Amount_T3__c is set to zero.');
    }

    // Scenario 3 — T1 splits deleted when T1_Opp__c is set to No
    @IsTest
    static void update_t1OppSetToNo_deletesT1Splits() {
        Id t1TypeId = getSplitTypeId('T1');

        Account acc = getAccount();
        enableAutomation();

        Opportunity opp = buildOpp(acc.Id, getOppOwnerId());

        opp.Net_Revenue_Forecast__c = 1000;
        insert opp;

        System.assertNotEquals(0, countSplits(opp.Id, t1TypeId),
            'T1 splits should exist after qualifying insert.');

        resetBetweenActions();

        // Disable T1 and clear revenue → delete handler removes splits.
        opp.T1_Opp__c               = 'No';
        opp.Net_Revenue_Forecast__c = 0;

        Test.startTest();
        update opp;
        Test.stopTest();

        System.assertEquals(0, countSplits(opp.Id, t1TypeId),
            'All T1 splits should be deleted when T1_Opp__c = No and revenue is zero.');
    }

    // Scenario 4 — Opp owner change removes the old owner's splits
    @IsTest
    static void update_ownerChange_staleOppOwnerSplitsRemovedAccOwnerPreserved() {
        Id t2TypeId = getSplitTypeId('T2');
        Id t3TypeId = getSplitTypeId('T3');

        User newOwner = TestDataFactory.createTestUser('e2e.newowner@e2etest.invalid', 'E2ENewOwner', 'e2eno');
        insert newOwner;
        Id newOwnerId = getUserIdByLastName('E2ENewOwner');

        Account acc         = getAccount();
        Id oldOppOwnerId    = getOppOwnerId();
        Id accOwnerId       = getAccOwnerId();

        enableAutomation();

        Opportunity opp = buildOpp(acc.Id, oldOppOwnerId);

        opp.Estimate_Managed_Service_Revenue__c = 500;
        opp.Total_Amount_T2__c                  = 500;
        opp.Total_Amount_T3__c                  = 200;
        insert opp;

        System.assertNotEquals(0, countSplitsByOwner(opp.Id, t2TypeId, oldOppOwnerId),
            'Old opp owner should have a T2 split before the owner change.');

        resetBetweenActions();

        opp.OwnerId = newOwnerId;

        Test.startTest();
        update opp;
        Test.stopTest();

        // Old opp owner's splits must be removed (stale-owner cleanup).
        System.assertEquals(0, countSplitsByOwner(opp.Id, t2TypeId, oldOppOwnerId),
            'Old opp owner T2 split should be removed after owner change.');
        System.assertEquals(0, countSplitsByOwner(opp.Id, t3TypeId, oldOppOwnerId),
            'Old opp owner T3 split should be removed after owner change.');

        // Account owner splits must remain.
        System.assertEquals(1, countSplitsByOwner(opp.Id, t2TypeId, accOwnerId),
            'Account owner T2 split should be preserved after owner change.');
        System.assertEquals(1, countSplitsByOwner(opp.Id, t3TypeId, accOwnerId),
            'Account owner T3 split should be preserved after owner change.');
    }

    // Scenario 5 — Account change removes the old account owner's splits
    @IsTest
    static void update_accountChange_staleAccountOwnerSplitsRemoved() {
        Id t2TypeId = getSplitTypeId('T2');

        // Create a second account with a different owner.
        User newAccOwner = TestDataFactory.createTestUser('e2e.newaccowner@e2etest.invalid', 'E2ENewAccOwner', 'e2enao');
        insert newAccOwner;
        Id newAccOwnerId = getUserIdByLastName('E2ENewAccOwner');
        Account acc2 = TestDataFactory.getAccount('E2EAccount2', newAccOwnerId, Date.newInstance(2025, 1, 1));
        insert acc2;

        Account acc         = getAccount();
        Id oppOwnerId       = getOppOwnerId();
        Id oldAccOwnerId    = getAccOwnerId();

        enableAutomation();

        Opportunity opp = buildOpp(acc.Id, oppOwnerId);

        opp.Estimate_Managed_Service_Revenue__c = 500;
        insert opp;

        System.assertEquals(1, countSplitsByOwner(opp.Id, t2TypeId, oldAccOwnerId),
            'Old account owner should have a T2 split before the account change.');

        resetBetweenActions();

        opp.AccountId = acc2.Id;

        Test.startTest();
        update opp;
        Test.stopTest();

        System.assertEquals(0, countSplitsByOwner(opp.Id, t2TypeId, oldAccOwnerId),
            'Old account owner T2 split should be removed after account change.');
    }

    // Scenario 6 — Admin repair: Run_Splits_Flow__c recreates missing splits
    @IsTest
    static void update_runSplitsFlowChecked_recreatesMissingSplitsAndUnchecksFlag() {
        Id t2TypeId = getSplitTypeId('T2');
        Id t3TypeId = getSplitTypeId('T3');

        Account acc     = getAccount();
        Id oppOwnerId   = getOppOwnerId();
        Id accOwnerId   = getAccOwnerId();

        // Insert with automation DISABLED — no splits are created.
        Opportunity opp = buildOpp(acc.Id, oppOwnerId);

        opp.T1_Opp__c               = 'Yes';
        opp.Total_Amount_T2__c      = 500;
        opp.Total_Amount_T3__c      = 200;
        insert opp;

        System.assertEquals(0, countSplits(opp.Id, t2TypeId),
            'No T2 splits should exist before automation is enabled.');
        System.assertEquals(0, countSplits(opp.Id, t3TypeId),
            'No T3 splits should exist before automation is enabled.');

        // Enable automation and trigger the admin repair checkbox.
        enableAutomation();
        resetBetweenActions();

        opp.Run_Splits_Flow__c = true;

        Test.startTest();
        update opp;
        Test.stopTest();

        // All eligible splits recreated for both owners.
        System.assertEquals(1, countSplitsByOwner(opp.Id, t2TypeId, oppOwnerId),
            'Admin repair should create T2 split for the opp owner.');
        System.assertEquals(1, countSplitsByOwner(opp.Id, t2TypeId, accOwnerId),
            'Admin repair should create T2 split for the account owner.');
        System.assertEquals(1, countSplitsByOwner(opp.Id, t3TypeId, oppOwnerId),
            'Admin repair should create T3 split for the opp owner.');
        System.assertEquals(1, countSplitsByOwner(opp.Id, t3TypeId, accOwnerId),
            'Admin repair should create T3 split for the account owner.');

        // The checkbox must be reset to false by the handler.
        Opportunity refreshed = [SELECT Run_Splits_Flow__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(false, refreshed.Run_Splits_Flow__c,
            'Run_Splits_Flow__c should be automatically unchecked after admin repair.');
    }

    // Scenario 8 — Run_Splits_Flow__c recreates splits even when the opportunity is closed
    @IsTest
    static void update_runSplitsFlowOnClosedOpp_recreatesMissingSplits() {
        Id t1TypeId = getSplitTypeId('T1');

        Account acc     = getAccount();
        Id oppOwnerId   = getOppOwnerId();

        // Insert with automation DISABLED so no splits are created.
        Opportunity opp = buildOpp(acc.Id, oppOwnerId);
        opp.T1_Opp__c               = 'Yes';
        opp.Net_Revenue_Forecast__c = 1000;
        insert opp;

        // Close the opportunity — automation is still disabled so nothing fires here.
        opp.StageName = 'Closed Won';
        update opp;

        System.assertEquals(0, countSplits(opp.Id, t1TypeId),
            'No T1 splits should exist before admin repair.');

        // Enable automation and trigger admin repair on the closed opportunity.
        enableAutomation();
        resetBetweenActions();

        opp.Run_Splits_Flow__c = true;

        Test.startTest();
        update opp;
        Test.stopTest();

        System.assertNotEquals(0, countSplits(opp.Id, t1TypeId),
            'Run_Splits_Flow__c should recreate T1 splits even on a closed opportunity.');

        Opportunity refreshed = [SELECT Run_Splits_Flow__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(false, refreshed.Run_Splits_Flow__c,
            'Run_Splits_Flow__c should be automatically unchecked after repair on a closed opportunity.');
    }

    // Scenario 7 — Automation disabled: no splits created on insert
    @IsTest
    static void insert_automationDisabled_noSplitsCreated() {
        Id t1TypeId = getSplitTypeId('T1');
        Id t2TypeId = getSplitTypeId('T2');
        Id t3TypeId = getSplitTypeId('T3');

        Account acc = getAccount();
        // Automation remains DISABLED as set in @TestSetup — no enableAutomation() call.

        Opportunity opp = buildOpp(acc.Id, getOppOwnerId());

        opp.Net_Revenue_Forecast__c             = 1000;
        opp.Estimate_Managed_Service_Revenue__c = 500;
        opp.Total_Amount_T3__c                  = 200;

        Test.startTest();
        insert opp;
        Test.stopTest();

        System.assertEquals(0, countSplits(opp.Id, t1TypeId),
            'No T1 splits should be created when automation is disabled.');
        System.assertEquals(0, countSplits(opp.Id, t2TypeId),
            'No T2 splits should be created when automation is disabled.');
        System.assertEquals(0, countSplits(opp.Id, t3TypeId),
            'No T3 splits should be created when automation is disabled.');
    }
}