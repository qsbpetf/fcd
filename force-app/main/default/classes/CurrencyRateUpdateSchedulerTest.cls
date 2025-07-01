/**
 * Created by peterfriberg on 2025-07-01.
 */

@IsTest
private class CurrencyRateUpdateSchedulerTest {

    /**
     * Mock HTTP response for the Exchange Rates API
     */
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        private Boolean returnSuccess;

        public MockHttpResponseGenerator(Boolean returnSuccess) {
            this.returnSuccess = returnSuccess;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (returnSuccess) {
                res.setStatusCode(200);
                res.setBody('{"success":true,"timestamp":1651449600,"base":"EUR","date":"2022-05-02","rates":{"USD":1.0523,"GBP":0.8386,"CAD":1.3454,"JPY":136.96}}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"success":false,"error":{"code":101,"type":"invalid_access_key","info":"You have not supplied a valid API Access Key."}}');
            }

            return res;
        }
    }

    /**
     * Test the scheduler can be scheduled and executes properly.
     */
    @IsTest
    static void testScheduler() {
        // Setup test data if needed

        // Set up a mock HTTP callout response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        // Start the test, this ensures any asynchronous processes are run synchronously
        Test.startTest();

        // Schedule the job
        String cronExp = '0 0 1 * * ?'; // 1 AM daily
        String jobId = System.schedule('Test Currency Rate Update', cronExp, new CurrencyRateUpdateScheduler());

        // Verify the job was scheduled
        List<CronTrigger> cronTriggers = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals(1, cronTriggers.size(), 'Job should be scheduled');
        System.assertEquals(cronExp, cronTriggers[0].CronExpression, 'Cron expression should match');

        // Directly call the execute method to test it
        CurrencyRateUpdateScheduler scheduler = new CurrencyRateUpdateScheduler();
        scheduler.execute(null);

        // Stop the test, this forces any asynchronous processes to complete
        Test.stopTest();

        // Add assertions as needed to verify the currency rates were updated
        // This might be difficult since updateCurrencyConversionRates performs callouts
        // and DML operations that aren't easily verified in a test context
    }

    /**
     * Test the direct updateCurrencyRates method.
     */
    @IsTest
    static void testUpdateCurrencyRates() {
        // Setup test data if needed

        // Set up a mock HTTP callout response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        // Start the test
        Test.startTest();

        // Call the method directly
        CurrencyRateUpdateScheduler.updateCurrencyRates();

        // Stop the test
        Test.stopTest();

        // Add assertions as needed
    }

    /**
     * Test error handling in the scheduler.
     */
    @IsTest
    static void testErrorHandling() {
        // Set up a mock HTTP callout that will fail
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false));

        // Start the test
        Test.startTest();

        // Call the method directly
        CurrencyRateUpdateScheduler.updateCurrencyRates();

        // Stop the test
        Test.stopTest();

        // Since we're expecting an error to be handled, there's not much to assert
        // The test passes if no unhandled exception is thrown
    }
}