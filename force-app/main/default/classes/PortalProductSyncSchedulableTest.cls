/**
 * Created by peterfriberg on 2024-12-09.
 */

@IsTest
private class PortalProductSyncSchedulableTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        PortalCommerceApiProducts.instance = new PortalCommerceApiProducts();
        PortalCommerceApiProducts.setApiClient(mockServiceStub);
    }

    @IsTest
    static void testSchedulableWithQueueable() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"values": [{"id": "c3e47a6b-a040-4725-a28a-8c13414f772e", "name": "Amazon CodeCatalyst Cloud", "ari": "ari:cloud:commerce::product/c3e47a6b-a040-4725-a28a-8c13414f772e", "updatedAt": 1705048090978, "supportedBillingSystems": ["HAMS", "CCP"], "version": 3, "status": "ACTIVE"}], "nextId": "c3e47a6b-a040-4725-a28a-8c13414f772e"}');

        mockService
            .when('getProducts')
            .thenReturn(response);

        // Initialize the schedulable class
        PortalProductSyncSchedulable schedulableInstance = new PortalProductSyncSchedulable();

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
        List<AtlassianProduct__c> products = [SELECT Id, Name, Status__c FROM AtlassianProduct__c];
        System.assertEquals(1, products.size(), 'Expected 1 InvoiceGroup__c record to be created.');
        System.assertEquals('Amazon CodeCatalyst Cloud', products[0].Name, 'Wrong name');
        System.assertEquals('ACTIVE', products[0].Status__c, 'Wrong status');
    }

}