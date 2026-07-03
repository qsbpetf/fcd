/**
 * Test class for TierCalcScheduledJob
 */
@isTest
private class TierCalcScheduledJobTest {

    @TestSetup
    static void setup() {
        // Create test data using TestDataFactory
        Account testAccount = TestDataFactory.getAccount('United States', 'USD');
        insert testAccount;

        // Create opportunities modified within last 24 hours
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 5; i++) {
            Opportunity opp = TestDataFactory.getOpp(testAccount.Id, 'USD');
            opp.Name = 'Test Opp ' + i;
            opp.StageName = 'Prospecting';
            opp.Amount = 10000;
            opps.add(opp);
        }
        insert opps;
    }

    @isTest
    static void testErrorNotification() {
        Profile sysAdminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String uniqueAdmin = 'admin' + DateTime.now().getTime() + '@test.com';

        User adminUser = new User(
            FirstName = 'Test',
            LastName = 'Admin',
            Email = 'admin@test.com',
            Username = uniqueAdmin,
            Alias = 'tadm',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = sysAdminProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert adminUser;

        Test.startTest();
        TierCalcScheduledJob jobInstance = new TierCalcScheduledJob();
        jobInstance.sendErrorNotification(null, 'Test Error Summary Notification Coverage');
        Test.stopTest();
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();

        // Execute the batch job
        TierCalcScheduledJob job = new TierCalcScheduledJob();
        Database.executeBatch(job, 200);

        Test.stopTest();

        // Verify the batch ran successfully
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'TierCalcScheduledJob'
            AND JobType = 'BatchApex'
        ];

        System.assertEquals(1, jobs.size(), 'Batch job should have been executed');
        System.assertEquals('Completed', jobs[0].Status, 'Batch job should complete successfully');
    }

    @isTest
    static void testBatchWithTargetIds() {
        // Get some test opportunities
        List<Opportunity> opps = [SELECT Id FROM Opportunity LIMIT 2];
        Set<Id> targetIds = new Set<Id>();
        for (Opportunity o : opps) {
            targetIds.add(o.Id);
        }

        Test.startTest();

        // Execute the batch job with targeted IDs
        TierCalcScheduledJob job = new TierCalcScheduledJob(targetIds);
        Database.executeBatch(job, 200);

        Test.stopTest();

        // Verify the batch ran successfully
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'TierCalcScheduledJob'
            AND JobType = 'BatchApex'
        ];

        System.assertEquals(1, jobs.size(), 'Batch job should have been executed');
        System.assertEquals('Completed', jobs[0].Status, 'Batch job should complete successfully');
    }

    @isTest
    static void testBatchWithCustomLookback() {
        Test.startTest();

        // Execute the batch job with 48 hour lookback
        TierCalcScheduledJob job = new TierCalcScheduledJob(48);
        Database.executeBatch(job, 200);

        Test.stopTest();

        // Verify the batch ran
        List<AsyncApexJob> jobs = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'TierCalcScheduledJob'
            AND JobType = 'BatchApex'
        ];

        System.assertEquals(1, jobs.size(), 'Batch job should have been executed');
    }

    @isTest
    static void testScheduledExecution() {
        String cronExp = '0 0 0 * * ?'; // Daily at midnight

        Test.startTest();

        // Schedule the job
        String jobId = TierCalcScheduledJob.schedule('Test Tier Calc Job', cronExp);

        Test.stopTest();

        // Verify the job was scheduled
        CronTrigger ct = [
            SELECT Id, CronExpression, State, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertNotEquals(null, ct, 'Scheduled job should exist');
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match');
        System.assertEquals('WAITING', ct.State, 'Job should be in WAITING state');
    }

    @isTest
    static void testAbortAll() {
        // Schedule multiple jobs
        TierCalcScheduledJob.schedule('Test Tier Calc Job 1', '0 0 0 * * ?');
        TierCalcScheduledJob.schedule('Test Tier Calc Job 2', '0 0 1 * * ?');

        Test.startTest();

        // Abort all scheduled jobs
        TierCalcScheduledJob.abortAll();

        Test.stopTest();

        // Verify all jobs were aborted
        List<CronTrigger> jobs = [
            SELECT Id, State
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE '%TierCalc%'
            AND State != 'DELETED'
        ];

        // Jobs should be deleted or in deleted state
        System.assertEquals(0, jobs.size(), 'All scheduled jobs should be aborted');
    }

    @isTest
    static void testNoOpportunitiesFound() {
        // Delete all opportunities
        delete [SELECT Id FROM Opportunity];

        Test.startTest();

        // Execute the batch job
        TierCalcScheduledJob job = new TierCalcScheduledJob();
        Database.executeBatch(job, 200);

        Test.stopTest();

        // Verify the batch completed without errors
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'TierCalcScheduledJob'
            AND JobType = 'BatchApex'
        ];

        System.assertEquals(1, jobs.size(), 'Batch job should have been executed');
        System.assertEquals('Completed', jobs[0].Status, 'Batch should complete even with no records');
        System.assertEquals(0, jobs[0].NumberOfErrors, 'Should have no errors');
    }

    @isTest
    static void testSchedulableInterface() {
        String cronExp = '0 0 0 * * ?';

        Test.startTest();

        // Create instance and schedule it
        TierCalcScheduledJob job = new TierCalcScheduledJob();
        String jobId = System.schedule('Test Schedulable Tier Calc', cronExp, job);

        Test.stopTest();

        // Verify the job was scheduled
        CronTrigger ct = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertNotEquals(null, ct, 'Scheduled job should exist');
    }
}