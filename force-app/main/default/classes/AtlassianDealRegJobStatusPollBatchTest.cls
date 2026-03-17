/**
 * Unit tests for AtlassianDealRegJobStatusPollBatch and AtlassianDealRegJobStatusPollScheduler.
 */
@IsTest
private class AtlassianDealRegJobStatusPollBatchTest {

    private static final String JOB_STATUS_RESPONSE = '{"jobId":"job-123","status":"COMPLETED","createdAt":"2024-01-15T10:00:00Z","lastModifiedAt":"2024-01-15T10:05:00Z","registrationId":"D-12345"}';

    @TestSetup
    static void setup() {
        AtlassianDealRegSubmission__c sub = new AtlassianDealRegSubmission__c(
            Name = 'Test Submission',
            Registration_Id__c = 'D-12345',
            Job_Id__c = 'job-123',
            Partner_Account_Id__c = '0012000000yYBawAAG',
            Status__c = 'IN_PROGRESS'
        );
        insert sub;
    }

    @IsTest
    static void testBatchPollsAndUpdatesStatus() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('jobs/v1', JOB_STATUS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AtlassianDealRegJobStatusPollBatch.run();
        Test.stopTest();

        AtlassianDealRegSubmission__c sub = [SELECT Status__c, Last_Polled__c, Error__c FROM AtlassianDealRegSubmission__c LIMIT 1];
        System.assertEquals('COMPLETED', sub.Status__c, 'Status should be updated');
        System.assertNotEquals(null, sub.Last_Polled__c, 'Last Polled should be set');
        System.assertEquals(null, sub.Error__c, 'Error should be null on success');
    }

    @IsTest
    static void testBatchSkipsNonInProgress() {
        AtlassianDealRegSubmission__c sub = [SELECT Id FROM AtlassianDealRegSubmission__c LIMIT 1];
        sub.Status__c = 'COMPLETED';
        update sub;

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('jobs/v1', JOB_STATUS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AtlassianDealRegJobStatusPollBatch.run();
        Test.stopTest();

        System.assertEquals(0, mock.getRequests().size(), 'Should not poll completed records');
    }

    @IsTest
    static void testSchedulerEnqueuesBatch() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('jobs/v1', JOB_STATUS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        System.schedule('Test Job Poll', '0 0 * * * ?', new AtlassianDealRegJobStatusPollScheduler());
        Test.stopTest();

        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Test Job Poll'];
        System.assertEquals(1, jobs.size(), 'Scheduled job should exist');
    }
}
