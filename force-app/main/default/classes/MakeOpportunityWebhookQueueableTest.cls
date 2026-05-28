@IsTest(isParallel=false)
private class MakeOpportunityWebhookQueueableTest {
    private static final String TEST_PRODUCT_CODE = 'MWOH_TEST_PRODUCT';

    @TestSetup
    static void testSetupData() {
        Id standardPbId = Test.getStandardPricebookId();

        Product2 product = new Product2(
            Name = 'MWOH Test Product',
            ProductCode = TEST_PRODUCT_CODE,
            IsActive = true,
            Family = 'OtherVendorProduct',
            Academic_Cost_price_Dollars__c = 10,
            Academic_Cost_price_Euros__c = 8,
            Academic_Cost_price_Pounds__c = 7,
            Commercial_Cost_price_Dollars__c = 20,
            Commercial_Cost_price_Euros__c = 16,
            Commercial_Cost_price_Pounds__c = 14
        );
        insert product;

        insert new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = product.Id,
            CurrencyIsoCode = 'EUR',
            UnitPrice = 1,
            IsActive = true
        );
    }

    @IsTest
    static void testStageChangeTriggersWebhook() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = true);

        // Use existing custom metadata configuration for stage name
        MakeWebhookOpportunityStageConfig__mdt config =
            [SELECT StageName__c FROM MakeWebhookOpportunityStageConfig__mdt WHERE IsTestRecord__c = TRUE LIMIT 1];

        String targetStage = config.StageName__c;

        // Create account with valid billing country & payment terms
        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        // Create an Opportunity with a different stage first
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = 'Order';
        opp.Payment_Terms__c = acc.Payment_terms__c;
        opp.Revenue_Types_Declarative__c = 'Services';
        insert opp;
        insertPricedOLI(opp.Id, 'EUR');

        // Set up HTTP mock
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        // Update stage to configured value to trigger webhook
        opp.StageName = targetStage;
        update opp;
        Test.stopTest();

        // Verify that exactly one webhook call (filtered by endpoint) was made with correct endpoint and payload
        List<HttpRequest> allRequests = mock.getRequests();
        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : allRequests) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOpportunityWebhookQueueable.OPPORTUNITY_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(1, requests.size(), 'Exactly one webhook call should be made');

        HttpRequest req = requests[0];
        System.assertEquals('POST', req.getMethod(), 'Webhook should use POST');
        System.assert(
            req.getEndpoint().contains(MakeOpportunityWebhookQueueable.OPPORTUNITY_WEBHOOK_PATH),
            'Endpoint should contain the opportunity webhook path'
        );

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
        System.assertEquals(
            (String) opp.Id,
            (String) body.get('OpportunityId'),
            'Body should contain correct OpportunityId'
        );
    }

    @IsTest
    static void testWebhookWhenOtherFieldsChangeInConfiguredStage() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = true);

        // Use existing custom metadata configuration for stage name
        MakeWebhookOpportunityStageConfig__mdt config =
            [SELECT StageName__c FROM MakeWebhookOpportunityStageConfig__mdt WHERE IsTestRecord__c = TRUE LIMIT 1];

        String targetStage = config.StageName__c;

        // Create account with valid billing country & payment terms
        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        // Create Opportunity already in the configured stage
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = targetStage;
        opp.Payment_Terms__c = acc.Payment_terms__c;
        opp.Revenue_Types_Declarative__c = 'Services';
        insert opp;
        insertPricedOLI(opp.Id, 'EUR');

        // Set up HTTP mock
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        // Update a non-stage field only - should still trigger webhook
        opp.Name = 'No Change Opportunity Updated';
        update opp;
        Test.stopTest();

        // Filter only the HTTP requests that go to this webhook endpoint
        List<HttpRequest> allRequests = mock.getRequests();
        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : allRequests) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOpportunityWebhookQueueable.OPPORTUNITY_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(
            1,
            requests.size(),
            'Exactly one webhook call should be made when other fields change in a configured stage'
        );
    }

    @IsTest
    static void testNoWebhookWhenDisabled() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = false);

        MakeWebhookOpportunityStageConfig__mdt config =
            [SELECT StageName__c FROM MakeWebhookOpportunityStageConfig__mdt WHERE IsTestRecord__c = TRUE LIMIT 1];

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = 'Order';
        opp.Payment_Terms__c = acc.Payment_terms__c;
        opp.Revenue_Types_Declarative__c = 'Services';
        insert opp;
        insertPricedOLI(opp.Id, 'EUR');

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        opp.StageName = config.StageName__c;
        update opp;
        Test.stopTest();

        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : mock.getRequests()) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOpportunityWebhookQueueable.OPPORTUNITY_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(0, requests.size(), 'No webhook call should be made when EnableOpportunityWebhook__c is false');
    }

    @IsTest
    static void testNoWebhookWhenRevenueTypeIsNull() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = true);

        MakeWebhookOpportunityStageConfig__mdt config =
            [SELECT StageName__c FROM MakeWebhookOpportunityStageConfig__mdt WHERE IsTestRecord__c = TRUE LIMIT 1];

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = 'Order';
        opp.Payment_Terms__c = acc.Payment_terms__c;
        opp.Revenue_Types_Declarative__c = null;
        insert opp;
        insertPricedOLI(opp.Id, 'EUR');

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        opp.StageName = config.StageName__c;
        update opp;
        Test.stopTest();

        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : mock.getRequests()) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOpportunityWebhookQueueable.OPPORTUNITY_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(0, requests.size(), 'No webhook call should be made when Revenue_Types_Declarative__c is null');
    }

    @IsTest
    static void testNoWebhookWhenRevenueTypeIsLicenses() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = true);

        MakeWebhookOpportunityStageConfig__mdt config =
            [SELECT StageName__c FROM MakeWebhookOpportunityStageConfig__mdt WHERE IsTestRecord__c = TRUE LIMIT 1];

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = 'Order';
        opp.Payment_Terms__c = acc.Payment_terms__c;
        opp.Revenue_Types_Declarative__c = 'Licenses';
        insert opp;
        insertPricedOLI(opp.Id, 'EUR');

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        opp.StageName = config.StageName__c;
        update opp;
        Test.stopTest();

        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : mock.getRequests()) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOpportunityWebhookQueueable.OPPORTUNITY_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(0, requests.size(), 'No webhook call should be made when Revenue_Types_Declarative__c is Licenses');
    }

    @IsTest
    static void testNoWebhookWhenClosedMoreThan15DaysAgo() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = true);

        String closedConfiguredStage = getConfiguredClosedStage();
        if (closedConfiguredStage == null) {
            System.assert(true, 'No configured closed stage available in metadata for test context');
            return;
        }

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = closedConfiguredStage;
        opp.Payment_Terms__c = acc.Payment_terms__c;
        opp.Revenue_Types_Declarative__c = 'Services';
        opp.CloseDate = Date.today().addDays(-20);
        insert opp;
        insertPricedOLI(opp.Id, 'EUR');

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        opp.Name = 'Closed old opportunity';
        update opp;
        Test.stopTest();

        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : mock.getRequests()) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOpportunityWebhookQueueable.OPPORTUNITY_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(0, requests.size(), 'No webhook call should be made when closed more than 15 days ago');
    }

    @IsTest
    static void testWebhookWhenClosedWithin15Days() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = true);

        String closedConfiguredStage = getConfiguredClosedStage();
        if (closedConfiguredStage == null) {
            System.assert(true, 'No configured closed stage available in metadata for test context');
            return;
        }

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = closedConfiguredStage;
        opp.Payment_Terms__c = acc.Payment_terms__c;
        opp.Revenue_Types_Declarative__c = 'Services';
        opp.CloseDate = Date.today().addDays(-10);
        insert opp;
        insertPricedOLI(opp.Id, 'EUR');

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        opp.Name = 'Closed recent opportunity';
        update opp;
        Test.stopTest();

        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : mock.getRequests()) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOpportunityWebhookQueueable.OPPORTUNITY_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(1, requests.size(), 'Webhook should be made when closed within 15 days');
    }

    @IsTest
    static void testNoWebhookWhenNoPricedOLIExists() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = true);

        MakeWebhookOpportunityStageConfig__mdt config =
            [SELECT StageName__c FROM MakeWebhookOpportunityStageConfig__mdt WHERE IsTestRecord__c = TRUE LIMIT 1];

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = 'Order';
        opp.Payment_Terms__c = acc.Payment_terms__c;
        opp.Revenue_Types_Declarative__c = 'Services';
        insert opp;

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        opp.StageName = config.StageName__c;
        update opp;
        Test.stopTest();

        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : mock.getRequests()) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOpportunityWebhookQueueable.OPPORTUNITY_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(0, requests.size(), 'No webhook call should be made when there is no OLI with UnitPrice');
    }

    private static void insertPricedOLI(Id oppId, String currencyIsoCode) {
        Id standardPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = [
            SELECT Id
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPbId
              AND CurrencyIsoCode = :currencyIsoCode
              AND Product2.ProductCode = :TEST_PRODUCT_CODE
            LIMIT 1
        ];

        update new Opportunity(Id = oppId, Pricebook2Id = standardPbId);

        OpportunityLineItem oli = TestDataFactory.getOppProd(pbe.Id, oppId);
        insert oli;
    }

    private static String getConfiguredClosedStage() {
        Set<String> configuredStages = new Set<String>();
        for (MakeWebhookOpportunityStageConfig__mdt m : [
            SELECT StageName__c
            FROM MakeWebhookOpportunityStageConfig__mdt
            WHERE IsTestRecord__c = TRUE AND IsActive__c = TRUE
        ]) {
            if (String.isNotBlank(m.StageName__c)) {
                configuredStages.add(m.StageName__c);
            }
        }

        if (configuredStages.isEmpty()) {
            return null;
        }

        List<OpportunityStage> stages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsClosed = TRUE AND MasterLabel IN :configuredStages
            LIMIT 1
        ];
        return stages.isEmpty() ? null : stages[0].MasterLabel;
    }
}