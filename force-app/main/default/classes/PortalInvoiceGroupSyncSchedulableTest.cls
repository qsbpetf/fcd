/**
 * Created by peterfriberg on 2024-09-25.
 */

@IsTest
private class PortalInvoiceGroupSyncSchedulableTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        PortalCommerceApiInvoiceGroups.instance = new PortalCommerceApiInvoiceGroups();
        PortalCommerceApiInvoiceGroups.setApiClient(mockServiceStub);
    }

    @IsTest
    static void testSchedulableWithQueueable() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","version":15,"name":"Invoice Group 1","slug":"SLUG","currency":"EUR","active":true,"shipToParty":{"name":"Ship To Party 1","id":"ABCDEF","taxId":"665544"}}]}');

        mockService
            .when('getInvoiceGroups')
            .thenReturn(response);

        // Initialize the schedulable class
        PortalInvoiceGroupSyncSchedulable schedulableInstance = new PortalInvoiceGroupSyncSchedulable();

        // Schedule the job
        String cronExpression = '0 0 12 * * ?';
        String jobId = System.schedule('TestScheduledJob', cronExpression, schedulableInstance);

        // Verify the job was scheduled
        CronTrigger ct = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals('WAITING', ct.State, 'Job should be in waiting state.');

        // Enqueue the job
        Test.startTest();
        schedulableInstance.execute(null);
        Test.stopTest();

        // Assertions to verify the expected outcome of the Queueable job
        // e.g., check records created or modified by the Queueable job
        List<InvoiceGroup__c> invoiceGroups = [SELECT Id, Name, CV_Subsidiary__c, CurrencyIsoCode FROM InvoiceGroup__c];
        System.assertEquals(1, invoiceGroups.size(), 'Expected 1 InvoiceGroup__c record to be created.');
        System.assertEquals('Invoice Group 1', invoiceGroups[0].Name, 'Wrong name');
        System.assertEquals('EUR', invoiceGroups[0].CurrencyIsoCode, 'Wrong currency');
    }
}