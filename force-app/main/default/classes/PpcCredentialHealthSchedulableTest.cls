@IsTest
private class PpcCredentialHealthSchedulableTest {

    @IsTest
    static void executeEnqueuesWhenEnabledByDefault() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data":[]}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        new PpcCredentialHealthSchedulable().execute(null);
        Test.stopTest();

        System.assert(
            [SELECT COUNT() FROM PpcCredentialStatus__c] > 0,
            'Scheduled execute should probe offices when no kill-switch record exists'
        );
    }

    @IsTest
    static void executeSkipsWhenDisabled() {
        PPC_HealthCheckSettings__c setting = new PPC_HealthCheckSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Enabled__c = false
        );
        insert setting;

        Test.startTest();
        new PpcCredentialHealthSchedulable().execute(null);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM PpcCredentialStatus__c], 'Disabled kill switch must skip probes');
    }

    @IsTest
    static void startSchedulesThreeJobs() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data":[]}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<String> jobIds = PpcCredentialHealthSchedulable.start();

        System.assertEquals(3, jobIds.size(), 'Should register one job per 20-minute slot');
        List<CronTrigger> jobs = [
            SELECT Id, State, CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE Id IN :jobIds
            ORDER BY CronExpression
        ];
        System.assertEquals(3, jobs.size());
        System.assertEquals('0 0 * * * ?', jobs[0].CronExpression);
        System.assertEquals('0 20 * * * ?', jobs[1].CronExpression);
        System.assertEquals('0 40 * * * ?', jobs[2].CronExpression);
        for (CronTrigger job : jobs) {
            System.assertEquals('WAITING', job.State);
        }
        Test.stopTest();
    }

    @IsTest
    static void stopAbortsScheduledJobs() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data":[]}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        List<String> jobIds = PpcCredentialHealthSchedulable.start();
        PpcCredentialHealthSchedulable.stop();
        Test.stopTest();

        List<CronTrigger> remaining = [
            SELECT Id, State
            FROM CronTrigger
            WHERE Id IN :jobIds
        ];
        for (CronTrigger job : remaining) {
            System.assertNotEquals('WAITING', job.State, 'Aborted jobs should not still be waiting');
        }
    }
}