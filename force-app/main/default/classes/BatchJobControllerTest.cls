/**
 * Created by peterfriberg on 2025-03-13.
 */

@IsTest
private class BatchJobControllerTest {

    @IsTest
    static void testStartInvoiceImportBatchJob() {
        Test.startTest();
        String result = BatchJobController.startInvoiceImportBatchJob(30);
        System.debug(result);
        Test.stopTest();
        System.assertNotEquals(null, result, 'The result should not be null');
    }

    @IsTest
    static void testReadingAsyncBatchJobRecord() {
        Test.startTest();
        String result = BatchJobController.startInvoiceImportBatchJob(30);
        AsyncApexJob job = BatchJobController.getAsyncApexJob(result);
        System.debug(job);
        Test.stopTest();
        System.assertNotEquals(null, job, 'The jobs should not be null');
    }

    @IsTest
    static void testReadingAsyncBatchJobRecords() {
        Test.startTest();
        String result = BatchJobController.startInvoiceImportBatchJob(30);
        List<AsyncApexJob> jobs = BatchJobController.getAsyncApexJobs();
        System.debug(jobs);
        Test.stopTest();
        System.assertNotEquals(null, jobs, 'The jobs should not be null');
        System.assertEquals(1, jobs.size(), 'Should have one job');
    }

    @IsTest
    static void testGetAsyncJobsNoJobs() {
        Test.startTest();
        List<BatchJobController.ApexJob> jobs = BatchJobController.getApexJobs();
        System.debug(jobs);
        Test.stopTest();
        System.assertNotEquals(null, jobs, 'The jobs should not be null');
        System.assertEquals(0, jobs.size(), 'Should have no jobs');
    }

    @IsTest
    static void testGetAsyncJobsOneJob() {
        Test.startTest();
        String result = BatchJobController.startInvoiceImportBatchJob(30);
        List<BatchJobController.ApexJob> jobs = BatchJobController.getApexJobs();
        System.debug(jobs);
        Test.stopTest();
        System.assertNotEquals(null, jobs, 'The jobs should not be null');
        System.assertEquals(1, jobs.size(), 'Should have one job');
        System.assertEquals(result, jobs[0].JobId, 'Should have the same job id');
    }
}