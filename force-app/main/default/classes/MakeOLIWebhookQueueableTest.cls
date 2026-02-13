@IsTest
private class MakeOLIWebhookQueueableTest {

    @IsTest
    static void testSingleLineItemDeleteTriggersWebhook() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = true);

        // Use configured stage from custom metadata
        MakeWebhookOpportunityStageConfig__mdt config =
            [SELECT StageName__c FROM MakeWebhookOpportunityStageConfig__mdt WHERE IsTestRecord__c = TRUE LIMIT 1];

        // Prepare data: account with valid billing country & payment terms, standard pricebook, product, pricebook entry, opportunity, line item
        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        // Standard pricebook & product data
        Id standardPbId = Test.getStandardPricebookId();

        Product2 product = TestDataFactory.getProduct();
        insert product;

        PricebookEntry pbe = TestDataFactory.getPbEntry(standardPbId, product.Id, 'EUR');
        insert pbe;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = config.StageName__c;
        opp.Payment_Terms__c = acc.Payment_terms__c;
        insert opp;

        OpportunityLineItem oli = TestDataFactory.getOppProd(pbe.Id, opp.Id);
        insert oli;

        // Set up HTTP mock
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        delete oli;
        Test.stopTest();

        // Filter only the HTTP requests that go to this webhook endpoint,
        // since other code in the transaction may also perform callouts.
        List<HttpRequest> allRequests = mock.getRequests();
        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : allRequests) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOLIWebhookQueueable.OLI_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(1, requests.size(), 'Exactly one webhook call should be made');

        HttpRequest req = requests[0];
        System.assertEquals('POST', req.getMethod(), 'Webhook should use POST');
        System.assert(
            req.getEndpoint().contains(MakeOLIWebhookQueueable.OLI_WEBHOOK_PATH),
            'Endpoint should contain the OLI webhook path'
        );

        Map<String, Object> body =
            (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
        System.assertEquals(
            (String) oli.Id,
            (String) body.get('OpportunityLineItemId'),
            'Body should contain correct OpportunityLineItemId'
        );
    }

    @IsTest
    static void testMultipleLineItemDeleteTriggersMultipleWebhooks() {
        upsert new MakeWebhookSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableOpportunityWebhook__c = true);

        MakeWebhookOpportunityStageConfig__mdt config =
            [SELECT StageName__c FROM MakeWebhookOpportunityStageConfig__mdt WHERE IsTestRecord__c = TRUE LIMIT 1];

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.BillingCountry = 'Finland';
        acc.Payment_terms__c = '10 Days';
        insert acc;

        Id standardPbId = Test.getStandardPricebookId();

        Product2 product = TestDataFactory.getProduct();
        insert product;

        PricebookEntry pbe = TestDataFactory.getPbEntry(standardPbId, product.Id, 'EUR');
        insert pbe;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = config.StageName__c;
        opp.Payment_Terms__c = acc.Payment_terms__c;
        insert opp;

        OpportunityLineItem oli1 = TestDataFactory.getOppProd(pbe.Id, opp.Id);
        OpportunityLineItem oli2 = TestDataFactory.getOppProd(pbe.Id, opp.Id);
        insert new List<OpportunityLineItem>{ oli1, oli2 };

        // Set up HTTP mock
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        delete new List<OpportunityLineItem>{ oli1, oli2 };
        Test.stopTest();

        List<HttpRequest> allRequests = mock.getRequests();
        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : allRequests) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOLIWebhookQueueable.OLI_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(2, requests.size(), 'One webhook call should be made per deleted OLI');

        Set<String> oliIdsFromRequests = new Set<String>();
        for (HttpRequest req : requests) {
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            oliIdsFromRequests.add((String) body.get('OpportunityLineItemId'));
        }

        System.assert(
            oliIdsFromRequests.contains((String) oli1.Id) &&
            oliIdsFromRequests.contains((String) oli2.Id),
            'Both deleted OpportunityLineItem Ids should be present in webhook calls'
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

        Id standardPbId = Test.getStandardPricebookId();
        Product2 product = TestDataFactory.getProduct();
        insert product;

        PricebookEntry pbe = TestDataFactory.getPbEntry(standardPbId, product.Id, 'EUR');
        insert pbe;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.StageName = config.StageName__c;
        opp.Payment_Terms__c = acc.Payment_terms__c;
        insert opp;

        OpportunityLineItem oli = TestDataFactory.getOppProd(pbe.Id, opp.Id);
        insert oli;

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        delete oli;
        Test.stopTest();

        List<HttpRequest> requests = new List<HttpRequest>();
        for (HttpRequest r : mock.getRequests()) {
            if (r.getEndpoint() != null &&
                r.getEndpoint().contains(MakeOLIWebhookQueueable.OLI_WEBHOOK_PATH)) {
                requests.add(r);
            }
        }

        System.assertEquals(0, requests.size(), 'No webhook call should be made when EnableOpportunityWebhook__c is false');
    }

    /**
     * Best-effort helper to populate any payment-term-related fields
     * on the given SObject so that org-level validation rules depending
     * on payment term information will pass in tests.
     */
    private static void setPaymentTermFields(SObject record) {
        Map<String, Schema.SObjectField> fieldMap =
            record.getSObjectType().getDescribe().fields.getMap();

        for (String apiName : fieldMap.keySet()) {
            String lower = apiName.toLowerCase();
            if (!lower.contains('payment') || !lower.contains('term')) {
                continue;
            }

            Schema.DescribeFieldResult describe = fieldMap.get(apiName).getDescribe();
            if (!describe.isCreateable() || describe.isCalculated() || describe.isAutoNumber()) {
                continue;
            }

            Schema.DisplayType type = describe.getType();

            // For restricted picklists, use a real picklist value from metadata
            if (type == Schema.DisplayType.Picklist) {
                List<Schema.PicklistEntry> entries = describe.getPicklistValues();
                if (!entries.isEmpty()) {
                    record.put(apiName, entries[0].getValue());
                }
            } else if (type == Schema.DisplayType.MultiPicklist) {
                List<Schema.PicklistEntry> entries = describe.getPicklistValues();
                if (!entries.isEmpty()) {
                    record.put(apiName, entries[0].getValue());
                }
            } else if (type == Schema.DisplayType.String ||
                       type == Schema.DisplayType.TextArea ||
                       type == Schema.DisplayType.Phone ||
                       type == Schema.DisplayType.Url ||
                       type == Schema.DisplayType.Email) {
                record.put(apiName, 'Test');
            } else if (type == Schema.DisplayType.Integer ||
                       type == Schema.DisplayType.Long ||
                       type == Schema.DisplayType.Double ||
                       type == Schema.DisplayType.Currency ||
                       type == Schema.DisplayType.Percent) {
                record.put(apiName, 1);
            }
        }
    }
}

