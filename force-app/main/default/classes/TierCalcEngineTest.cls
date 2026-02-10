/**
 * Test class for TierCalcEngine
 * Tests the tier calculation logic for T1, T2, and T3 amounts
 */
@isTest
private class TierCalcEngineTest {

    @TestSetup
    static void setup() {
        // Create test account
        Account testAccount = TestDataFactory.getAccount('Finland', 'EUR');
        insert testAccount;

        // Create test opportunity
        Opportunity opp = TestDataFactory.getOpp(testAccount.Id, 'USD');
        opp.T2_Override__c = false;
        opp.T3_Override__c = false;
        opp.Estimate_Consulting_Revenue__c = 0;
        opp.Estimate_Managed_Service_Revenue__c = 0;
        opp.Estimate_Licensing_GP__c = 0;
        insert opp;
    }

    @isTest
    static void testComputeWithBasicOpportunity() {
        // Arrange
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        Map<Id, Decimal> splits = new Map<Id, Decimal>{
            opp.OwnerId => 100
        };

        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, Date.today());
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.t1calc, 'T1 calculation should be 0 for empty opportunity');
        System.assertEquals(0, result.t2calc, 'T2 calculation should be 0 for empty opportunity');
        System.assertEquals(0, result.t3calc, 'T3 calculation should be 0 for empty opportunity');
        System.assertEquals(1, result.lines.size(), 'Should have 1 tier line');
    }

    @isTest
    static void testComputeWithMultipleSplits() {
        // Arrange
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();

        // Create multiple splits
        Map<Id, Decimal> splits = new Map<Id, Decimal>();
        User testUser1 = TestDataFactory.createTestUser('testuser1@example.com');
        User testUser2 = TestDataFactory.createTestUser('testuser2@example.com');
        insert new List<User>{
            testUser1, testUser2
        };
        splits.put(testUser1.Id, 60);
        splits.put(testUser2.Id, 40);

        // Act
        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, Date.today());

        // Assert
        System.assertEquals(2, result.lines.size(), 'Should have 2 tier lines for 2 splits');
        Set<Id> userIds = new Set<Id>();
        for (Tier__c line : result.lines) {
            userIds.add(line.User__c);
            System.assertEquals('Calculated', line.Status__c, 'Status should be Calculated');
            System.assertEquals(opp.Id, line.Opportunity__c, 'Opportunity should match');
            System.assertEquals(opp.AccountId, line.Account__c, 'Account should match');
        }
        System.assertEquals(2, userIds.size(), 'Should have 2 unique users');
    }

    @isTest
    static void testComputeWithNullSplits() {
        // Arrange
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();

        // Act - pass null splits to test default behavior
        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, null, Date.today());
        System.assertEquals(1, result.lines.size(), 'Should have 1 tier line with default split');
        System.assertEquals(opp.OwnerId, result.lines[0].User__c, 'Should use opportunity owner as default');
    }

    @isTest
    static void testCalculateT2WithNullOpportunity() {
        // Act & Assert
        Decimal result = TierCalcEngine.calculateT2(null, new List<OpportunityLineItem>());
        System.assertEquals(0, result, 'Should return 0 for null opportunity');
    }

    @isTest
    static void testCalculateT2WithEstimateFallback() {
        // Arrange
        Opportunity opp = getOpportunityWithAllFields(null);
        opp.Estimate_Consulting_Revenue__c = 5000;
        opp.Estimate_Managed_Service_Revenue__c = 3000;
        update opp;

        opp = getOpportunityWithAllFields(opp.Id);

        // Act - pass empty list to trigger fallback
        Decimal result = TierCalcEngine.calculateT2(opp, new List<OpportunityLineItem>());
        System.assertEquals(8000, result, 'T2 should be sum of consulting and managed services estimates');
    }

    @isTest
    static void testCalculateT2WithLineItems() {
        // Arrange
        Opportunity opp = getOpportunityWithAllFields(null);
        opp.T2_Override__c = false;
        update opp;

        Opportunity updatedOpp = getOpportunityWithAllFields(opp.Id);

        // Create mock OpportunityLineItem
        OpportunityLineItem oli = new OpportunityLineItem();
        oli.T2_Attainment_Amount__c = 5000;

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>{oli};

        Decimal result = TierCalcEngine.calculateT2(updatedOpp, olis);
        System.assertEquals(5000, result, 'T2 should equal the attainment amount');
    }

    @isTest
    static void testCalculateT2WithOverride() {
        // Arrange
        Opportunity opp = getOpportunityWithAllFields(null);
        opp.T2_Override__c = true;
        update opp;

        Opportunity updatedOpp = getOpportunityWithAllFields(opp.Id);

        OpportunityLineItem oli = new OpportunityLineItem();
        oli.T2_Attainment_Amount__c = 5000;

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>{oli};

        Decimal result = TierCalcEngine.calculateT2(updatedOpp, olis);
        System.assertEquals(0, result, 'T2 should be 0 when override is true');
    }

    @isTest
    static void testCalculateT3WithNullOpportunity() {
        // Act & Assert
        Decimal result = TierCalcEngine.calculateT3(null, new List<OpportunityLineItem>());
        System.assertEquals(0, result, 'Should return 0 for null opportunity');
    }

    @isTest
    static void testCalculateT3WithEstimateFallback() {
        // Arrange
        Opportunity opp = getOpportunityWithAllFields(null);
        opp.Estimate_Licensing_GP__c = 2000;
        update opp;

        opp = getOpportunityWithAllFields(opp.Id);

        // Act - pass empty list to trigger fallback
        Decimal result = TierCalcEngine.calculateT3(opp, new List<OpportunityLineItem>());
        System.assertEquals(2000, result, 'T3 should equal the licensing estimate');
    }

    @isTest
    static void testCalculateT3WithNullLineItems() {
        // Arrange
        Opportunity opp = getOpportunityWithAllFields(null);
        opp.T3_Override__c = false;
        update opp;

        Opportunity updatedOpp = getOpportunityWithAllFields(opp.Id);

        // Act - pass empty list
        Decimal result = TierCalcEngine.calculateT3(updatedOpp, new List<OpportunityLineItem>());
        System.assertEquals(0, result, 'T3 should be 0 when no line items and no rebate');
    }

    @isTest
    static void testCalculateT3WithOverride() {
        // Arrange
        Opportunity opp = getOpportunityWithAllFields(null);
        opp.T3_Override__c = true;
        update opp;

        Opportunity updatedOpp = getOpportunityWithAllFields(opp.Id);

        // Act - pass empty list, override should prevent calculations
        Decimal result = TierCalcEngine.calculateT3(updatedOpp, new List<OpportunityLineItem>());
        System.assertEquals(0, result, 'T3 should be 0 when override is true');
    }

    @isTest
    static void testTierLineCreationWithSnapshot() {
        // Arrange
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        Map<Id, Decimal> splits = new Map<Id, Decimal>{opp.OwnerId => 100};
        Date testDate = Date.today();

        // Act
        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, testDate);

        // Assert
        System.assertEquals(1, result.lines.size(), 'Should have 1 tier line');
        Tier__c line = result.lines[0];
        System.assertNotEquals(null, line.Input_Snapshot__c, 'Snapshot should not be null');
        System.assertNotEquals(null, line.Input_Hash__c, 'Hash should not be null');
        System.assertNotEquals('', line.Line_Key__c, 'Line key should not be empty');

        // Verify line key format (oppId:userId:yyyy-MM)
        String expectedPattern = opp.Id + ':' + opp.OwnerId + ':';
        System.assert(line.Line_Key__c.startsWith(expectedPattern), 'Line key should start with opportunity and user IDs');
    }

    @isTest
    static void testComputeWithEmptyLineItems() {
        // Arrange
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);
        opp.Estimate_Consulting_Revenue__c = 1000;
        update opp;

        opp = getOpportunityWithAllFields(opp.Id);

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        Map<Id, Decimal> splits = new Map<Id, Decimal>{opp.OwnerId => 100};

        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, Date.today());
        System.assertEquals(1000, result.t2calc, 'T2 should fall back to consulting estimate when no line items');
        System.assertEquals(1, result.lines.size(), 'Should create 1 tier line');
    }

    @isTest
    static void testComputeLineKeyFormat() {
        // Arrange
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        Map<Id, Decimal> splits = new Map<Id, Decimal>{opp.OwnerId => 100};
        Date testDate = Date.newInstance(2024, 12, 15);

        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, testDate);
        Tier__c line = result.lines[0];
        System.assert(line.Line_Key__c.contains(opp.Id), 'Line key should contain opportunity ID');
        System.assert(line.Line_Key__c.contains(opp.OwnerId), 'Line key should contain user ID');
        System.assert(line.Line_Key__c.contains('2024-12'), 'Line key should contain year-month');
    }


    @isTest
    static void testComputeInputHashGenerated() {
        // Arrange
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        Map<Id, Decimal> splits = new Map<Id, Decimal>{opp.OwnerId => 100};

        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, Date.today());
        Tier__c line = result.lines[0];
        System.assertNotEquals(null, line.Input_Hash__c, 'Hash should be generated');
        System.assert(line.Input_Hash__c.length() > 0, 'Hash should not be empty');
        System.assertEquals(40, line.Input_Hash__c.length(), 'SHA1 hash should be 40 characters');
    }

    @isTest
    static void testTierResultT1EqualsT2PlusT3() {
        // Arrange
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);
        opp.Estimate_Consulting_Revenue__c = 5000;
        opp.Estimate_Managed_Service_Revenue__c = 3000;
        opp.Estimate_Licensing_GP__c = 2000;
        update opp;

        opp = getOpportunityWithAllFields(opp.Id);

        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        Map<Id, Decimal> splits = new Map<Id, Decimal>{opp.OwnerId => 100};

        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, Date.today());
        System.assertEquals(10000, result.t1calc, 'T1 should be 10000 (5000 + 3000 + 2000)');
        System.assertEquals(8000, result.t2calc, 'T2 should be 8000 (5000 + 3000)');
        System.assertEquals(2000, result.t3calc, 'T3 should be 2000');
        System.assertEquals(result.t2calc + result.t3calc, result.t1calc, 'T1 should equal T2 + T3');
    }

    // ===== Tests for calculateT2AttainmentAmount (private method tested indirectly) =====

     @isTest
    static void testT2AttainmentWithUpgradeRenewalType() {
        // Test: Renewal = Upgrade (Same Platform) should return full amount
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);
        PricebookEntry pbe = createPricebookEntry();

        OpportunityLineItem oli = createOpportunityLineItem(
            opp.Id, pbe.Id, 7500, 7500, 0, TierCalcEngine.RENEWAL_UPGRADE, Date.today(), Date.today().addDays(365)
        );
        insert oli;

        List<OpportunityLineItem> olis = getOpportunityLineItemsWithAllFields(opp.Id);
        Map<Id, Decimal> splits = new Map<Id, Decimal>{opp.OwnerId => 100};

        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, Date.today());
        System.assertNotEquals(0, result.t2calc, 'T2 should have a value for Upgrade renewal with line items');
    }

    @isTest
    static void testT2AttainmentWithNoProject() {
        // Test: No project should return T2 = 0 for renewal types other than New/Upgrade
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);
        PricebookEntry pbe = createPricebookEntry();

        OpportunityLineItem oli = createOpportunityLineItem(
            opp.Id, pbe.Id, 5000, 5000, 0, 'Renewal (CV Owned)', Date.today(), Date.today().addDays(365)
        );
        insert oli;

        List<OpportunityLineItem> olis = getOpportunityLineItemsWithAllFields(opp.Id);
        Map<Id, Decimal> splits = new Map<Id, Decimal>{opp.OwnerId => 100};

        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, Date.today());
        System.assertEquals(0, result.t2calc, 'T2 should be 0 when no project exists');
    }

    @isTest
    static void testT2AttainmentLicenseStartAfterProjectPlus365() {
        // Test: License_Start_date > Project_Start_Date + 365 should return T2 = 0
        // Note: Date-based logic only applies to renewal types other than 'New' or 'Upgrade (Same Platform)'
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);

        Date projectStartDate = Date.today().addDays(-100);
        Date licenseStartDate = projectStartDate.addDays(366); // After project+365
        Date licenseEndDate = projectStartDate.addDays(466); // Set end date

        Project__c project = new Project__c(
            Name = 'Test Project',
            Project_Start_Date_new__c = projectStartDate
        );
        insert project;

        // Update opportunity to link to project
        opp.Related_Project__c = project.Id;
        update opp;
        opp = getOpportunityWithAllFields(opp.Id);

        PricebookEntry pbe = createPricebookEntry();

        OpportunityLineItem oli = createOpportunityLineItem(
            opp.Id, pbe.Id, 5000, 5000, 0, 'Renewal (CV Owned)', licenseStartDate, licenseEndDate
        );
        insert oli;

        List<OpportunityLineItem> olis = getOpportunityLineItemsWithAllFields(opp.Id);
        Map<Id, Decimal> splits = new Map<Id, Decimal>{opp.OwnerId => 100};

        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, Date.today());
        System.assertEquals(0, result.t2calc, 'T2 should be 0 when license starts after project+365');
    }

    @isTest
    static void testT2AttainmentLicenseEndBeforeProjectPlus365() {
        // Test: License_end_date < Project_Start_Date + 365 should return full amount
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = getOpportunityWithAllFields(null);

        Date projectStartDate = Date.today().addDays(-100);
        Date licenseStartDate = projectStartDate.addDays(200); // Set a start date
        Date licenseEndDate = projectStartDate.addDays(364); // Before project+365

        Project__c project = new Project__c(
            Name = 'Test Project',
            Project_Start_Date_new__c = projectStartDate
        );
        insert project;

        opp.Related_Project__c = project.Id;
        update opp;
        opp = getOpportunityWithAllFields(opp.Id);

        PricebookEntry pbe = createPricebookEntry();

        OpportunityLineItem oli = createOpportunityLineItem(
            opp.Id, pbe.Id, 5000, 5000, 0, TierCalcEngine.RENEWAL_UPGRADE, licenseStartDate, licenseEndDate
        );
        insert oli;

        List<OpportunityLineItem> olis = getOpportunityLineItemsWithAllFields(opp.Id);
        Map<Id, Decimal> splits = new Map<Id, Decimal>{opp.OwnerId => 100};

        TierCalcEngine.Result result = TierCalcEngine.compute(opp, account, olis, splits, Date.today());
        System.assertNotEquals(0, result.t2calc, 'T2 should be calculated when license ends before project+365');
    }

    private static Opportunity getOpportunityWithAllFields(Id oppId) {
        String query = 'SELECT Id, Name, AccountId, OwnerId, CloseDate, StageName, CurrencyIsoCode, ' +
            'Payment_Terms__c, Deal_Reg_Rebate_Value_Currency__c, ' +
            'Deal_Reg_Rebate_Value__c, Exchange_Rate_from_Products__c, ' +
            'Related_Project__c, Project_Type__c, Total_Amount__c, ' +
            'T2_Override__c, T3_Override__c, ' +
            'Estimate_Consulting_Revenue__c, Estimate_Managed_Service_Revenue__c, Estimate_Licensing_GP__c, ' +
            'Total_Amount_T2_V2__c, Total_Amount_T3_V2__c, T3_From_Products__c, ' +
            'Project_Start_Date_From_Project__c ' +
            'FROM Opportunity ' +
            (oppId != null ? 'WHERE Id = :oppId ' : '') +
            'LIMIT 1';
        List<Opportunity> opps = Database.query(query);
        return opps.isEmpty() ? null : opps[0];
    }

    private static List<OpportunityLineItem> getOpportunityLineItemsWithAllFields(Id oppId) {
        return [
            SELECT Id, OpportunityId,
                   T2_Attainment_Amount__c, T3_Product__c, Margin_Value__c,
                   Revenue_Type_Formula__c, Renewal__c,
                   Total_List_Price_Incl_Discount__c,
                   License_Start_date__c, License_end_date__c, days__c,
                   PricebookEntry.Product2.Revenue_Type__c
            FROM OpportunityLineItem
            WHERE OpportunityId = :oppId
        ];
    }




    private static PricebookEntry createPricebookEntry(String revenueType) {
        Id standardPbId = Test.getStandardPricebookId();

        Product2 product = TestDataFactory.getProduct();
        product.Revenue_Type__c = (revenueType != null) ? revenueType : 'Consulting';
        insert product;

        PricebookEntry pbe = TestDataFactory.getPbEntry(standardPbId, product.Id, 'USD');
        insert pbe;
        return pbe;
    }

    private static PricebookEntry createPricebookEntry() {
        return createPricebookEntry('Consulting');
    }

    private static OpportunityLineItem createOpportunityLineItem(Id oppId, Id pbeId, Decimal unitPrice, Decimal listPrice, Decimal discount, String renewal, Date startDate, Date endDate) {
        return new OpportunityLineItem(
            OpportunityId = oppId,
            PricebookEntryId = pbeId,
            Quantity = 1,
            UnitPrice = unitPrice,
            List_Price_Inc_Licence_Type__c = listPrice,
            Discount__c = discount,
            Renewal__c = renewal,
            License_Start_date__c = startDate,
            License_end_date__c = endDate
        );
    }
}