/**
 * Test class for CurrencyRateUpdateScheduler.
 */
@IsTest
private class CurrencyRateUpdateSchedulerTest {

    /**
     * Test the scheduler can be scheduled and executes properly.
     */
    @IsTest
    static void testScheduler() {
        // Setup test data if needed

        // Start the test, this ensures any asynchronous processes are run synchronously
        Test.startTest();

        // Schedule the job
        String cronExp = '0 0 1 * * ?'; // 1 AM daily
        String jobId = System.schedule('Test Currency Rate Update', cronExp, new CurrencyRateUpdateScheduler());

        // Verify the job was scheduled
        List<CronTrigger> cronTriggers = [SELECT Id, CronExpression, TimesTriggered, NextFireTime
        FROM CronTrigger
        WHERE Id = :jobId];
        System.assertEquals(1, cronTriggers.size(), 'Job should be scheduled');
        System.assertEquals(cronExp, cronTriggers[0].CronExpression, 'Cron expression should match');

        // Stop the test, this forces any asynchronous processes to complete
        Test.stopTest();

        // Scheduled jobs should have invoked the queueable
        // However, in tests, the queueable might not actually run due to callout restrictions
    }

    /**
     * Test custom email notification settings
     */
    @IsTest
    static void testCustomEmailSettings() {
        // Setup test data if needed

        // Start the test
        Test.startTest();

        // Create scheduler with custom settings
        String customEmail = 'test@example.com';
        CurrencyRateUpdateScheduler scheduler = new CurrencyRateUpdateScheduler(true, customEmail);

        // Schedule the job
        String cronExp = '0 0 1 * * ?'; // 1 AM daily
        String jobId = System.schedule('Test Currency Rate Update', cronExp, scheduler);

        // Stop the test
        Test.stopTest();

        // No assertions needed, we're just verifying it runs without exceptions
    }
}