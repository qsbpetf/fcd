/**
 * Created by peterfriberg on 2025-01-08.
 */

@IsTest
private class PortalOfferingsSyncSchedulableTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        PortalCommerceApiOfferings.instance = new PortalCommerceApiOfferings();
        PortalCommerceApiOfferings.setApiClient(mockServiceStub);
    }

    @IsTest
    static void testSchedulableWithBatch() {
        // SELECT Id, Name, AtlassianId__c FROM AtlassianProduct__c
        AtlassianProduct__c product = new AtlassianProduct__c();
        product.Name = 'Amazon CodeCatalyst Cloud';
        product.AtlassianId__c = 'c3e47a6b-a040-4725-a28a-8c13414f772e';
        insert product;

        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"values": [{"id": "4fc4a838-69af-440a-8e8b-62c37047e14b", "name": "Standard", "ari": "ari:cloud:commerce::offering/4fc4a838-69af-440a-8e8b-62c37047e14b", "updatedAt": 1714011354874, "hostingType": "CLOUD", "level": 400, "productId": "2ea3b1f0-2e1a-4ea3-bd1d-e5c4e241d332", "slugs": ["4fc4a838-69af-440a-8e8b-62c37047e14b-std"], "pricingType": "PAID", "status": "ACTIVE", "supportedBillingSystems": ["CCP", "HAMS"], "version": 7, "chargeElements": {}, "expiryDate": null, "trial": {"lengthDays": 30}, "offeringGroup": null}], "nextId": null}');

        mockService
            .when('getOfferings')
            .thenReturn(response);

        // Initialize the schedulable class
        PortalOfferingsSyncSchedulable schedulableInstance = new PortalOfferingsSyncSchedulable();

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

        List<AtlassianOffering__c> offerings = new List<AtlassianOffering__c>([
            SELECT Id, Name, Status__c
            FROM AtlassianOffering__c
        ]);

        System.assertEquals(1, offerings.size(), 'Expected 1 AtlassianOffering__c record to be created.');
        System.assertEquals('ACTIVE', offerings[0].Status__c, 'Wrong status');
        System.assertEquals('Standard', offerings[0].Name, 'Wrong name');
    }
}