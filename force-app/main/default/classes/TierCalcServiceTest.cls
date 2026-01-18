/**
 * Test class for TierCalcService
 * Focuses on integration testing of data loading, calculation orchestration, and persistence
 * Does not duplicate calculation logic tests (see TierCalcEngineTest for detailed calculation tests)
 */
@isTest
private class TierCalcServiceTest {

    @TestSetup
    static void setup() {
        // Create test account
        Account testAccount = TestDataFactory.getAccount('Finland', 'EUR');
        insert testAccount;

        // Create test users for splits
        List<User> testUsers = new List<User>();
        testUsers.add(TestDataFactory.createTestUser('split1@test.com'));
        testUsers.add(TestDataFactory.createTestUser('split2@test.com'));
        insert testUsers;

        // Create test opportunity
        Opportunity opp = TestDataFactory.getOpp(testAccount.Id, 'USD');
        opp.T2_Override__c = false;
        opp.T3_Override__c = false;
        opp.Estimate_Consulting_Revenue__c = 5000;
        opp.Estimate_Managed_Service_Revenue__c = 3000;
        opp.Estimate_Licensing_GP__c = 2000;
        insert opp;

        // Create opportunity splits
        OpportunitySplit split1 = new OpportunitySplit(
            OpportunityId = opp.Id,
            SplitOwnerId = testUsers[0].Id,
            SplitPercentage = 60
        );
        OpportunitySplit split2 = new OpportunitySplit(
            OpportunityId = opp.Id,
            SplitOwnerId = testUsers[1].Id,
            SplitPercentage = 40
        );
        insert new List<OpportunitySplit>{split1, split2};

        // Create products and line items
        Id standardPbId = Test.getStandardPricebookId();
        Product2 product = TestDataFactory.getProduct();
        product.Revenue_Type__c = 'Consulting';
        insert product;

        PricebookEntry pbe = TestDataFactory.getPbEntry(standardPbId, product.Id, 'USD');
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1000,
            List_Price_Inc_Licence_Type__c = 1000,
            Discount__c = 0,
            Renewal__c = 'New',
            License_Start_date__c = Date.today(),
            License_end_date__c = Date.today().addDays(365)
        );
        insert oli;
    }

    @isTest
    static void testCalculateFor_BasicScenario() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Set<Id> oppIds = new Set<Id>{opp.Id};

        List<Tier__c> result = TierCalcService.calculateFor(oppIds, Date.today());
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should create tier lines');

        List<Tier__c> savedLines = [SELECT Id, Opportunity__c, User__c, T1_Amount__c, T2_Amount__c, T3_Amount__c
                                     FROM Tier__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(result.size(), savedLines.size(), 'All tier lines should be saved');
    }

    @isTest
    static void testCalculateFor_WithMultipleSplits() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Set<Id> oppIds = new Set<Id>{opp.Id};

        List<Tier__c> result = TierCalcService.calculateFor(oppIds, Date.today());

        // Assert - should have 3 tier lines (2 splits created in setup + current user)
        System.assertEquals(3, result.size(), 'Should create tier lines for each split');

        List<Tier__c> savedLines = [SELECT Id, User__c FROM Tier__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(3, savedLines.size(), 'Should have 3 tier lines for 3 splits');
    }

    @isTest
    static void testCalculateFor_NullOrEmptyInput() {
        // Act & Assert - null input
        List<Tier__c> result1 = TierCalcService.calculateFor(null, Date.today());
        System.assertEquals(null, result1, 'Should return null for null input');

        // Act & Assert - empty set
        List<Tier__c> result2 = TierCalcService.calculateFor(new Set<Id>(), Date.today());
        System.assertEquals(null, result2, 'Should return null for empty input');
    }

    @isTest
    static void testCalculateFor_UpdatesOpportunityFields() {
        Opportunity opp = [SELECT Id, Total_Amount_T2_V2__c, Total_Amount_T3_V2__c FROM Opportunity LIMIT 1];
        Set<Id> oppIds = new Set<Id>{opp.Id};

        TierCalcService.calculateFor(oppIds, Date.today());

        // Assert - Opportunity T2 and T3 fields should be updated
        Opportunity updatedOpp = [SELECT Total_Amount_T2_V2__c, Total_Amount_T3_V2__c
                                   FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, updatedOpp.Total_Amount_T2_V2__c, 'T2_V2 should be calculated');
        System.assertNotEquals(null, updatedOpp.Total_Amount_T3_V2__c, 'T3_V2 should be calculated');
    }

    @isTest
    static void testCalculateFor_UpsertLogic_NewLines() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Set<Id> oppIds = new Set<Id>{opp.Id};

        // Verify no existing tier lines
        List<Tier__c> existingLines = [SELECT Id FROM Tier__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(0, existingLines.size(), 'Should start with no tier lines');

        TierCalcService.calculateFor(oppIds, Date.today());
        List<Tier__c> savedLines = [SELECT Id FROM Tier__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(3, savedLines.size(), 'Should create 3 new tier lines');
    }

    @isTest
    static void testCalculateFor_DeletesObsoleteSplits() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Set<Id> oppIds = new Set<Id>{opp.Id};

        // First calculation to create initial lines
        TierCalcService.calculateFor(oppIds, Date.today());

        List<Tier__c> initialLines = [SELECT Id FROM Tier__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(3, initialLines.size(), 'Should have 3 initial tier lines');

        // Remove one split
        List<OpportunitySplit> splits = [SELECT Id FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitOwnerId != :UserInfo.getUserId() LIMIT 1];
        delete splits;

        // Act - recalculate
        TierCalcService.calculateFor(oppIds, Date.today());
        List<Tier__c> updatedLines = [SELECT Id FROM Tier__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(2, updatedLines.size(), 'Should delete tier line for removed split');
    }

    @isTest
    static void testCalculateFor_WithProject() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        // Create a project linked to the opportunity
        Project__c project = new Project__c(
            Name = 'Test Project',
            Opportunity_Name__c = opp.Id,
            Project_Start_Date_new__c = Date.today(),
            Project_End_Date_new__c = Date.today().addDays(365)
        );
        insert project;

        Set<Id> oppIds = new Set<Id>{opp.Id};

        List<Tier__c> result = TierCalcService.calculateFor(oppIds, Date.today());
        System.assertNotEquals(null, result, 'Should handle opportunities with projects');
        System.assert(result.size() > 0, 'Should create tier lines with project');
    }

    @isTest
    static void testCalculateFor_MultipleOpportunities() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];

        Opportunity opp2 = TestDataFactory.getOpp(testAccount.Id, 'USD');
        opp2.Estimate_Consulting_Revenue__c = 3000;
        insert opp2;

        Opportunity opp1 = [SELECT Id FROM Opportunity LIMIT 1];
        Set<Id> oppIds = new Set<Id>{opp1.Id, opp2.Id};

        List<Tier__c> result = TierCalcService.calculateFor(oppIds, Date.today());
        System.assertNotEquals(null, result, 'Should handle multiple opportunities');

        // Verify tier lines for both opportunities
        List<Tier__c> opp1Lines = [SELECT Id FROM Tier__c WHERE Opportunity__c = :opp1.Id];
        List<Tier__c> opp2Lines = [SELECT Id FROM Tier__c WHERE Opportunity__c = :opp2.Id];
        System.assert(opp1Lines.size() > 0, 'Should create tier lines for first opportunity');
        System.assert(opp2Lines.size() > 0, 'Should create tier lines for second opportunity');
    }

    @isTest
    static void testCalculateFor_NoChangesNoUpsert() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Set<Id> oppIds = new Set<Id>{opp.Id};

        // First calculation
        TierCalcService.calculateFor(oppIds, Date.today());

        List<Tier__c> initialLines = [SELECT Id, Input_Hash__c, LastModifiedDate FROM Tier__c WHERE Opportunity__c = :opp.Id];

        // Act - recalculate without changes
        List<Tier__c> result = TierCalcService.calculateFor(oppIds, Date.today());
        // Assert - should return empty list (no changes)
        System.assertEquals(0, result.size(), 'Should not upsert when nothing changed');
    }

    @isTest
    static void testCalculateFor_WithLineKey() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Set<Id> oppIds = new Set<Id>{opp.Id};
        Date asOfDate = Date.newInstance(2024, 12, 15);

        TierCalcService.calculateFor(oppIds, asOfDate);
        // Assert - verify line keys are generated correctly
        List<Tier__c> savedLines = [SELECT Line_Key__c, User__c FROM Tier__c WHERE Opportunity__c = :opp.Id];
        for (Tier__c line : savedLines) {
            System.assertNotEquals(null, line.Line_Key__c, 'Line key should be set');
            System.assert(line.Line_Key__c.contains(opp.Id), 'Line key should contain opportunity ID');
            System.assert(line.Line_Key__c.contains(line.User__c), 'Line key should contain user ID');
            System.assert(line.Line_Key__c.contains('2024-12'), 'Line key should contain year-month');
        }
    }

}