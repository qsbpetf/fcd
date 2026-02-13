@IsTest
private class MakeOpportunityWebhookQueueableTest {

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
        insert opp;

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
        insert opp;

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

        System.assertEquals(0, requests.size(), 'No webhook call should be made when EnableOpportunityWebhook__c is false');
    }
}

