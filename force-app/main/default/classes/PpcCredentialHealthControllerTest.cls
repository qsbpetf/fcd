@IsTest
private class PpcCredentialHealthControllerTest {

    @IsTest
    static void getStatusesReturnsRowsWithLabelsAndStaleFlag() {
        insert new PpcCredentialStatus__c(
            Name = 'Eficode_Office_FI',
            NamedCredentialName__c = 'Eficode_Office_FI',
            CV_Subsidiary__c = 'FI',
            Status__c = PortalCommerceApiClient.STATUS_HEALTHY,
            HttpStatusCode__c = 200,
            LastChecked__c = Datetime.now().addMinutes(-60),
            ConsecutiveFailures__c = 0,
            ResponseTimeMs__c = 120
        );
        insert new PpcCredentialStatus__c(
            Name = 'Eficode_Office_SE',
            NamedCredentialName__c = 'Eficode_Office_SE',
            CV_Subsidiary__c = 'SE',
            Status__c = PortalCommerceApiClient.STATUS_UNHEALTHY,
            HttpStatusCode__c = 401,
            LastChecked__c = Datetime.now(),
            ConsecutiveFailures__c = 3,
            ErrorMessage__c = 'unauthorized'
        );

        Test.startTest();
        List<PpcCredentialHealthController.StatusRow> rows = PpcCredentialHealthController.getStatuses();
        Test.stopTest();

        System.assertEquals(2, rows.size());
        System.assertEquals('Finland', rows[0].subsidiaryLabel);
        System.assertEquals(true, rows[0].isStale, '60 minutes old should be stale with a 20-minute schedule');
        System.assertEquals('Sweden', rows[1].subsidiaryLabel);
        System.assertEquals(false, rows[1].isStale);
        System.assertEquals(401, rows[1].httpStatusCode);
    }

    @IsTest
    static void probeNowEnqueuesJob() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data":[]}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String jobId = PpcCredentialHealthController.probeNow();
        Test.stopTest();

        System.assertNotEquals(null, jobId);
        System.assert([SELECT COUNT() FROM PpcCredentialStatus__c] > 0);
    }

    @IsTest
    static void probeNowThrowsWhenAlreadyRunning() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data":[]}');
        Test.setMock(HttpCalloutMock.class, mock);

        PpcCredentialHealthQueueable.forceOverlap = true;

        Test.startTest();
        try {
            PpcCredentialHealthController.probeNow();
            System.assert(false, 'Expected AuraHandledException');
        } catch (Exception e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }
}
