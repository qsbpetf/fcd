/**
 * Test class for TierCalcController
 * Focuses on testing the controller layer logic for LWC/Quick Action and Flow integration
 * Does not duplicate calculation logic tests (see TierCalcEngineTest and TierCalcServiceTest)
 */
@isTest
private class TierCalcControllerTest {

    @TestSetup
    static void setup() {
        // Create test account
        Account testAccount = TestDataFactory.getAccount('Finland', 'EUR');
        insert testAccount;

        // Create test users for tier assignments
        List<User> testUsers = new List<User>();
        testUsers.add(TestDataFactory.createTestUser('tier1@test.com'));
        testUsers.add(TestDataFactory.createTestUser('tier2@test.com'));
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

        // Create tier records manually for getTierLines test
        List<Tier__c> tiers = new List<Tier__c>();
        tiers.add(new Tier__c(
            Opportunity__c = opp.Id,
            Account__c = testAccount.Id,
            User__c = testUsers[0].Id,
            T1_Amount__c = 6000,
            T2_Amount__c = 4800,
            T3_Amount__c = 1200,
            Status__c = 'Calculated'
        ));
        tiers.add(new Tier__c(
            Opportunity__c = opp.Id,
            Account__c = testAccount.Id,
            User__c = testUsers[1].Id,
            T1_Amount__c = 4000,
            T2_Amount__c = 3200,
            T3_Amount__c = 800,
            Status__c = 'Calculated'
        ));
        insert tiers;
    }

    @isTest
    static void testGetTierLines_WithExistingTiers() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        List<TierCalcController.LineDTO> lines = TierCalcController.getTierLines(opp.Id);
        System.assertNotEquals(null, lines, 'Lines should not be null');
        System.assertEquals(2, lines.size(), 'Should return 2 tier lines');

        // Verify first line (sorted by LastModifiedDate DESC, so could be either user)
        TierCalcController.LineDTO line1 = lines[0];
        System.assertNotEquals(null, line1.id, 'Line ID should not be null');
        System.assertNotEquals(null, line1.userName, 'User name should not be null');
        System.assertEquals('Calculated', line1.status, 'Status should be Calculated');
        System.assertNotEquals(null, line1.lastModified, 'LastModified should not be null');

        // Verify amounts are populated
        System.assertNotEquals(null, line1.t1Amount, 'T1 Amount should not be null');
        System.assertNotEquals(null, line1.t2Amount, 'T2 Amount should not be null');
        System.assertNotEquals(null, line1.t3Amount, 'T3 Amount should not be null');

        // Verify all tier lines have valid user names
        Set<String> userNames = new Set<String>();
        for (TierCalcController.LineDTO line : lines) {
            System.assertNotEquals(null, line.userName, 'All lines should have user names');
            userNames.add(line.userName);
        }
    }

    @isTest
    static void testGetTierLines_WithNoTiers() {
        // Arrange
        Account testAccount = TestDataFactory.getAccount('Finland', 'USD');
        insert testAccount;
        Opportunity emptyOpp = TestDataFactory.getOpp(testAccount.Id, 'USD');
        insert emptyOpp;

        List<TierCalcController.LineDTO> lines = TierCalcController.getTierLines(emptyOpp.Id);
        System.assertNotEquals(null, lines, 'Lines should not be null');
        System.assertEquals(0, lines.size(), 'Should return empty list when no tiers exist');
    }

    @isTest
    static void testRecalculateTiers_MultipleInputs() {
        Account testAccount = TestDataFactory.getAccount('Finland', 'USD');
        insert testAccount;

        Opportunity opp1 = [SELECT Id FROM Opportunity LIMIT 1];

        Opportunity opp2 = TestDataFactory.getOpp(testAccount.Id, 'USD');
        opp2.Estimate_Consulting_Revenue__c = 3000;
        insert opp2;

        List<User> users = [SELECT Id FROM User WHERE Email LIKE '%tier%@test.com' LIMIT 1];
        OpportunitySplit split = new OpportunitySplit(
            OpportunityId = opp2.Id,
            SplitOwnerId = users[0].Id,
            SplitPercentage = 100
        );
        insert split;

        TierCalcController.FlowInput input1 = new TierCalcController.FlowInput();
        input1.opportunityId = opp1.Id;

        TierCalcController.FlowInput input2 = new TierCalcController.FlowInput();
        input2.opportunityId = opp2.Id;

        List<TierCalcController.FlowInput> inputs = new List<TierCalcController.FlowInput>{input1, input2};

        List<TierCalcController.FlowOutput> outputs = TierCalcController.recalculateTiers(inputs);
        System.assertEquals(2, outputs.size(), 'Should return 2 outputs for 2 inputs');
        for (TierCalcController.FlowOutput output : outputs) {
            System.assertEquals(true, output.success, 'All calculations should succeed');
            System.assertNotEquals(null, output.lines, 'All outputs should have lines');
            System.assertNotEquals(null, output.lineCount, 'All outputs should have line count');
        }
    }


    @isTest
    static void testRecalculateTiers_EmptyInputList() {
        List<TierCalcController.FlowInput> inputs = new List<TierCalcController.FlowInput>();
        List<TierCalcController.FlowOutput> outputs = TierCalcController.recalculateTiers(inputs);
        System.assertNotEquals(null, outputs, 'Outputs should not be null');
        System.assertEquals(0, outputs.size(), 'Should return empty list for empty input');
    }

    @isTest
    static void testLineDTO_DataTransfer() {
        // Arrange
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<Tier__c> tiers = [SELECT Id, T1_Amount__c, T2_Amount__c, T3_Amount__c, Status__c, LastModifiedDate FROM Tier__c WHERE Opportunity__c = :opp.Id LIMIT 1];
        System.assert(tiers.size() > 0, 'Should have tier records for testing');

        Tier__c tier = tiers[0];

        List<TierCalcController.LineDTO> lines = TierCalcController.getTierLines(opp.Id);

        // Assert - Verify DTO correctly transfers all data
        TierCalcController.LineDTO matchingLine = null;
        for (TierCalcController.LineDTO line : lines) {
            if (line.id == tier.Id) {
                matchingLine = line;
                break;
            }
        }

        System.assertNotEquals(null, matchingLine, 'Should find matching line DTO');
        System.assertEquals(tier.Id, matchingLine.id, 'IDs should match');
        System.assertEquals(tier.T1_Amount__c, matchingLine.t1Amount, 'T1 amounts should match');
        System.assertEquals(tier.T2_Amount__c, matchingLine.t2Amount, 'T2 amounts should match');
        System.assertEquals(tier.T3_Amount__c, matchingLine.t3Amount, 'T3 amounts should match');
        System.assertEquals(tier.Status__c, matchingLine.status, 'Status should match');
        System.assertEquals(tier.LastModifiedDate, matchingLine.lastModified, 'LastModified should match');
    }

    @isTest
    static void testRecalcResult_DataStructure() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        TierCalcController.RecalcResult result = TierCalcController.recalcNow(opp.Id);

        // Assert - Verify RecalcResult wrapper contains all expected data
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.success != null, 'Success flag should be set');
        System.assertNotEquals(null, result.message, 'Message should not be null');
        System.assertNotEquals(null, result.lines, 'Lines should not be null');
    }

}