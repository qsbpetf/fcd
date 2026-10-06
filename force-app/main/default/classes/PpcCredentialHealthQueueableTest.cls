@IsTest
private class PpcCredentialHealthQueueableTest {

    private static Integer expectedOfficeCount() {
        return PPC_TransactionAccount__mdt.getAll().size();
    }

    @IsTest
    static void probeAllOfficesHealthy() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data":[]}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        PpcCredentialHealthQueueable.probeAllOffices();
        Test.stopTest();

        List<PpcCredentialStatus__c> statuses = [
            SELECT NamedCredentialName__c, Status__c, HttpStatusCode__c, ConsecutiveFailures__c,
                LastChecked__c, LastSuccess__c, ErrorMessage__c, CV_Subsidiary__c
            FROM PpcCredentialStatus__c
        ];
        System.assertEquals(expectedOfficeCount(), statuses.size(), 'One status row per PPC transaction account');
        System.assertEquals(expectedOfficeCount(), mock.getRequests().size(), 'One callout per office');
        for (PpcCredentialStatus__c rec : statuses) {
            System.assertEquals(PortalCommerceApiClient.STATUS_HEALTHY, rec.Status__c, rec.NamedCredentialName__c);
            System.assertEquals(200, rec.HttpStatusCode__c);
            System.assertEquals(0, rec.ConsecutiveFailures__c);
            System.assertNotEquals(null, rec.LastSuccess__c);
            System.assertEquals(null, rec.ErrorMessage__c);
            System.assert(rec.NamedCredentialName__c.startsWith('Eficode_Office_'), rec.NamedCredentialName__c);
        }
    }

    @IsTest
    static void probeMapsClientErrorAndServerError() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock(200, 'OK', '{"data":[]}');
        mock.addErrorResponse('Eficode_Office_FI', 400, '{"error":"unauthorized"}');
        mock.addErrorResponse('Eficode_Office_SE', 503, '{"error":"unavailable"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        PpcCredentialHealthQueueable.probeAllOffices();
        Test.stopTest();

        PpcCredentialStatus__c fi = [
            SELECT Status__c, HttpStatusCode__c, ConsecutiveFailures__c, ErrorMessage__c, LastFailure__c
            FROM PpcCredentialStatus__c
            WHERE NamedCredentialName__c = 'Eficode_Office_FI'
        ];
        PpcCredentialStatus__c se = [
            SELECT Status__c, HttpStatusCode__c, ConsecutiveFailures__c, ErrorMessage__c
            FROM PpcCredentialStatus__c
            WHERE NamedCredentialName__c = 'Eficode_Office_SE'
        ];

        System.assertEquals(PortalCommerceApiClient.STATUS_UNHEALTHY, fi.Status__c);
        System.assertEquals(400, fi.HttpStatusCode__c);
        System.assertEquals(1, fi.ConsecutiveFailures__c);
        System.assertNotEquals(null, fi.LastFailure__c);
        System.assert(fi.ErrorMessage__c.contains('unauthorized'));

        System.assertEquals(PortalCommerceApiClient.STATUS_OTHER_ERROR, se.Status__c);
        System.assertEquals(503, se.HttpStatusCode__c);
        System.assertEquals(1, se.ConsecutiveFailures__c);
    }

    @IsTest
    static void consecutiveFailuresIncrementAndReset() {
        insert new PpcCredentialStatus__c(
            Name = 'Eficode_Office_FI',
            NamedCredentialName__c = 'Eficode_Office_FI',
            CV_Subsidiary__c = 'FI',
            Status__c = PortalCommerceApiClient.STATUS_UNHEALTHY,
            ConsecutiveFailures__c = 2,
            HttpStatusCode__c = 400
        );

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data":[]}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        PpcCredentialHealthQueueable.probeAllOffices();
        Test.stopTest();

        PpcCredentialStatus__c fi = [
            SELECT Status__c, ConsecutiveFailures__c
            FROM PpcCredentialStatus__c
            WHERE NamedCredentialName__c = 'Eficode_Office_FI'
        ];
        System.assertEquals(PortalCommerceApiClient.STATUS_HEALTHY, fi.Status__c);
        System.assertEquals(0, fi.ConsecutiveFailures__c, 'Healthy probe should reset consecutive failures');
    }

    @IsTest
    static void sameStatusReprobeDoesNotCreateDuplicates() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data":[]}');
        Test.setMock(HttpCalloutMock.class, mock);

        PpcCredentialHealthQueueable.probeAllOffices();
        Integer firstCount = [SELECT COUNT() FROM PpcCredentialStatus__c];

        Test.startTest();
        PpcCredentialHealthQueueable.probeAllOffices();
        Test.stopTest();

        System.assertEquals(firstCount, [SELECT COUNT() FROM PpcCredentialStatus__c], 'Upsert must not create duplicates');
    }

    @IsTest
    static void enqueueRunsQueueable() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data":[]}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Id jobId = PpcCredentialHealthQueueable.enqueue();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job should be enqueued');
        System.assertEquals(expectedOfficeCount(), [SELECT COUNT() FROM PpcCredentialStatus__c]);
    }

    @IsTest
    static void enqueueSkipsWhenJobAlreadyQueued() {
        PpcCredentialHealthQueueable.forceOverlap = true;

        Test.startTest();
        Id jobId = PpcCredentialHealthQueueable.enqueue();
        Test.stopTest();

        System.assertEquals(null, jobId, 'Enqueue should be skipped when a job is already running');
        System.assertEquals(0, [SELECT COUNT() FROM PpcCredentialStatus__c]);
    }
}