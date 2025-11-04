/**
 * Test class for CurrencyRateUpdateQueueable.
 */
@IsTest
private class CurrencyRateUpdateQueueableTest {

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
     * Test the queueable execution with a successful callout
     */
    @IsTest
    static void testSuccessfulExecution() {
        // Set up a mock HTTP callout response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true));

        // Create the queueable
        CurrencyRateUpdateQueueable queueable = new CurrencyRateUpdateQueueable();

        // Start the test, this ensures any asynchronous processes are run synchronously
        Test.startTest();

        // Enqueue the job
        System.enqueueJob(queueable);

        // Stop the test, this forces any asynchronous processes to complete
        Test.stopTest();

        // Since we're testing a callout that doesn't have a direct return value,
        // we mainly verify that no exceptions are thrown.
        // Additional assertions could be added if your CurrencyCtrl makes changes
        // to records that could be queried after execution.
    }

    /**
     * Test error handling in the queueable
     */
    @IsTest
    static void testErrorHandling() {
        // Set up a mock HTTP callout that will fail
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false));

        // Create the queueable
        CurrencyRateUpdateQueueable queueable = new CurrencyRateUpdateQueueable();

        // Start the test
        Test.startTest();

        // Enqueue the job
        System.enqueueJob(queueable);

        // Stop the test
        Test.stopTest();

        // Since we're expecting an error to be handled, there's not much to assert
        // The test passes if no unhandled exception is thrown
    }

    /**
     * Test custom email notification settings
     */
    @IsTest
    static void testCustomEmailSettings() {
        // Set up a mock HTTP callout that will fail
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false));

        // Create the queueable with custom settings
        String customEmail = 'test@example.com';
        CurrencyRateUpdateQueueable queueable = new CurrencyRateUpdateQueueable(true, customEmail);

        // Start the test
        Test.startTest();

        // Enqueue the job
        System.enqueueJob(queueable);

        // Stop the test
        Test.stopTest();

        // No assertions needed, we're just verifying it runs without exceptions
    }
}