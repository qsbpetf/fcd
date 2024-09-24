/**
 * Created by peterfriberg on 2024-09-24.
 */

@IsTest
private class PortalCommerceApiInvoiceGroupsTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        PortalCommerceApiInvoiceGroups.instance = new PortalCommerceApiInvoiceGroups();
        PortalCommerceApiInvoiceGroups.setApiClient(mockServiceStub);
    }

    @IsTest
    static void testGetInstance() {
        PortalCommerceApiInvoiceGroups.instance = null;
        PortalCommerceApiInvoiceGroups instance = PortalCommerceApiInvoiceGroups.getInstance();
        System.assertNotEquals(null, instance, 'Instance should not be null');
        System.assertNotEquals(null, PortalCommerceApiInvoiceGroups.client, 'Client should not be null');
    }

    @IsTest
    static void testGetInvoiceGroupsSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","version":15,"name":"Invoice Group 1","slug":"SLUG","currency":"EUR","active":true,"shipToParty":{"name":"Ship To Party 1","id":"ABCDEF","taxId":"665544"}}]}');

        mockService
            .when('getInvoiceGroups')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoiceGroups instance = PortalCommerceApiInvoiceGroups.getInstance();
        PortalCommerceApiInvoiceGroups.InvoiceGroupList invoiceGroups = instance.getInvoiceGroups('FI', 10, null);
        Test.stopTest();

        System.debug('INVOICE GROUPS = ' + invoiceGroups);
        System.assertNotEquals(null, invoiceGroups, 'Invoice Groups should not be null');
        System.assertEquals(1, invoiceGroups.data.size(), 'Should have one invoice group');
        System.assertEquals('123456', invoiceGroups.data[0].id, 'Wrong invoice group number');
        System.assertEquals(15, invoiceGroups.data[0].version, 'Wrong invoice group version');
        System.assertEquals('Invoice Group 1', invoiceGroups.data[0].name, 'Wrong invoice group name');
        System.assertEquals('SLUG', invoiceGroups.data[0].slug, 'Wrong invoice group slug');
        System.assertEquals('EUR', invoiceGroups.data[0].isoCurrency, 'Wrong invoice group currency');
        System.assertEquals(true, invoiceGroups.data[0].active, 'Wrong invoice group active');
        System.assertEquals('Ship To Party 1', invoiceGroups.data[0].shipToParty.name, 'Wrong ship to party name');
        System.assertEquals('ABCDEF', invoiceGroups.data[0].shipToParty.id, 'Wrong ship to party id');
        System.assertEquals('665544', invoiceGroups.data[0].shipToParty.taxId, 'Wrong ship to party tax id');
    }

    @IsTest
    static void testCreateInvoiceGroupList() {
        PortalCommerceApiInvoiceGroups.InvoiceGroupList invoiceGroups = new PortalCommerceApiInvoiceGroups.InvoiceGroupList();
        System.assertNotEquals(null, invoiceGroups, 'Invoice Groups should not be null');
        System.assertEquals(0, invoiceGroups.data.size(), 'Should have no invoice groups');
        System.assertEquals(null, invoiceGroups.error, 'Error should be null');
        System.assertEquals(false, invoiceGroups.missingAccountId, 'Missing account id should be false');
    }
}