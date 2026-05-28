@isTest
private class AccountActiveProductsControllerTest {

    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Product2 testProduct = new Product2(Name = 'Test License Product', IsActive = true);
        insert testProduct;

        Id standardPbId = Test.getStandardPricebookId();

        PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert standardPbe;

        Opportunity oppOrder = new Opportunity(
            Name = 'Test Opp - Order',
            AccountId = testAccount.Id,
            StageName = 'Order',
            CloseDate = Date.today().addDays(-30),
            Pricebook2Id = standardPbId
        );
        insert oppOrder;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = oppOrder.Id,
            PricebookEntryId = standardPbe.Id,
            Quantity = 1000,
            UnitPrice = 100.00,
            License_Start_date__c = Date.today().addMonths(-6),
            License_end_date__c = Date.today().addMonths(6),
            Renewal__c = 'Renewal (CV Owned)'
        );
        insert oli;

        Opportunity oppProspecting = new Opportunity(
            Name = 'Test Opp - Prospecting',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPbId
        );
        insert oppProspecting;

        OpportunityLineItem oliExcluded = new OpportunityLineItem(
            OpportunityId = oppProspecting.Id,
            PricebookEntryId = standardPbe.Id,
            Quantity = 500,
            UnitPrice = 50.00,
            License_Start_date__c = Date.today(),
            License_end_date__c = Date.today().addMonths(12),
            Renewal__c = 'New'
        );
        insert oliExcluded;
    }

    @isTest
    static void testGetActiveProducts_ReturnsOrderStageOnly() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Test.startTest();
        List<OpportunityLineItem> results = AccountActiveProductsController.getActiveProducts(acc.Id);
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Should return only 1 record from Order stage');
        System.assertEquals(1000, results[0].Quantity, 'Quantity should be 1000');
        System.assertEquals('Renewal (CV Owned)', results[0].Renewal__c, 'Product Type mismatch');
    }

    @isTest
    static void testGetActiveProducts_NoResults() {
        Account emptyAccount = new Account(Name = 'Empty Account');
        insert emptyAccount;
        Test.startTest();
        List<OpportunityLineItem> results = AccountActiveProductsController.getActiveProducts(emptyAccount.Id);
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Should return empty list');
    }

    @isTest
    static void testGetActiveProducts_NullAccountId() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AccountActiveProductsController.getActiveProducts(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Exception should be thrown for null Account ID');
    }

    @isTest
    static void testGetActiveProducts_FieldsPopulated() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Test.startTest();
        List<OpportunityLineItem> results = AccountActiveProductsController.getActiveProducts(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, results[0].Product2.Name, 'Product Name should be populated');
        System.assertNotEquals(null, results[0].Opportunity.Name, 'Opportunity Name should be populated');
    }
}