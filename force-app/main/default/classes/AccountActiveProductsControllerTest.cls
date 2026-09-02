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
        AccountActiveProductsController.ActiveProductsResult result =
            AccountActiveProductsController.getActiveProducts(acc.Id, null);
        Test.stopTest();

        System.assertEquals(1, result.records.size(), 'Should return only 1 record from Order stage');
        System.assertEquals(1, result.totalCount, 'Total count should be 1');
        System.assertEquals(1000, result.records[0].Quantity, 'Quantity should be 1000');
        System.assertEquals('Renewal (CV Owned)', result.records[0].Renewal__c, 'Product Type mismatch');
    }

    @isTest
    static void testGetActiveProducts_PreviewLimitAndTotalCount() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Opportunity oppOrder = [SELECT Id FROM Opportunity WHERE Name = 'Test Opp - Order' LIMIT 1];
        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry
            WHERE Product2.Name = 'Test License Product' LIMIT 1
        ];

        // Setup'taki 1 kayıtla birlikte toplam 15 Order OLI olacak şekilde 14 kayıt ekle
        List<OpportunityLineItem> extraOlis = new List<OpportunityLineItem>();
        for (Integer i = 0; i < 14; i++) {
            extraOlis.add(new OpportunityLineItem(
                OpportunityId = oppOrder.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 10 + i,
                UnitPrice = 100.00,
                License_Start_date__c = Date.today().addMonths(-6),
                License_end_date__c = Date.today().addMonths(i),
                Renewal__c = 'Renewal (CV Owned)'
            ));
        }
        insert extraOlis;

        Test.startTest();
        // Preview: sadece 10 kayıt dönmeli ama totalCount 15 olmalı
        AccountActiveProductsController.ActiveProductsResult preview =
            AccountActiveProductsController.getActiveProducts(acc.Id, 10);
        // View All: limit null -> hepsi dönmeli
        AccountActiveProductsController.ActiveProductsResult full =
            AccountActiveProductsController.getActiveProducts(acc.Id, null);
        Test.stopTest();

        System.assertEquals(10, preview.records.size(), 'Preview should return exactly 10 records');
        System.assertEquals(15, preview.totalCount, 'Total count should reflect all Order records');
        System.assertEquals(15, full.records.size(), 'Null limit should return all records');
        System.assertEquals(15, full.totalCount, 'Total count should be 15');
    }

    @isTest
    static void testGetActiveProducts_NoResults() {
        Account emptyAccount = new Account(Name = 'Empty Account');
        insert emptyAccount;

        Test.startTest();
        AccountActiveProductsController.ActiveProductsResult result =
            AccountActiveProductsController.getActiveProducts(emptyAccount.Id, 10);
        Test.stopTest();

        System.assertEquals(0, result.records.size(), 'Should return empty list');
        System.assertEquals(0, result.totalCount, 'Total count should be 0');
    }

    @isTest
    static void testGetActiveProducts_NullAccountId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            AccountActiveProductsController.getActiveProducts(null, 10);
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
        AccountActiveProductsController.ActiveProductsResult result =
            AccountActiveProductsController.getActiveProducts(acc.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result.records[0].Product2.Name, 'Product Name should be populated');
        System.assertNotEquals(null, result.records[0].Opportunity.Name, 'Opportunity Name should be populated');
    }
}