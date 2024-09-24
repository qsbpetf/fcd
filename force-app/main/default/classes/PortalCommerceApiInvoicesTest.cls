/**
 * Created by peterfriberg on 2024-09-24.
 */

@IsTest
private class PortalCommerceApiInvoicesTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        PortalCommerceApiInvoices.instance = new PortalCommerceApiInvoices();
        PortalCommerceApiInvoices.setApiClient(mockServiceStub);
    }

    @IsTest
    static void testGetInstance() {
        PortalCommerceApiInvoices.instance = null;
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        System.assertNotEquals(null, instance, 'Instance should not be null');
        System.assertNotEquals(null, PortalCommerceApiInvoices.client, 'Client should not be null');
    }

    @IsTest
    static void testGetInvoicesSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","number":"123","items":[]}]}');

        mockService
            .when('getInvoices')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        PortalCommerceApiInvoices.InvoiceList invoices = instance.getInvoices('FI', 'INV_GRP', 10, null);
        Test.stopTest();

        System.debug('INVOICES = ' + invoices);
        System.assertNotEquals(null, invoices, 'Invoices should not be null');
        System.assertEquals(1, invoices.data.size(), 'Should have one invoice');
        System.assertEquals('123', invoices.data[0].invoiceNumber, 'Wrong invoice number');
        System.assertEquals('123456', invoices.data[0].id, 'Wrong invoice number');
    }

    @IsTest
    static void testgetInvoicesNot200Ok() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setStatus('Internal Server Error');
        response.setBody('{"error":"Internal Server Error"}');

        mockService
            .when('getInvoices')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        PortalCommerceApiInvoices.InvoiceList invoices = instance.getInvoices('FI', 'INV_GRP', 10, null);
        Test.stopTest();

        System.debug('INVOICES = ' + invoices);

        System.assertNotEquals(null, invoices, 'Invoices should not be null');
        System.assertEquals(true, invoices.missingAccountId, 'Should have missing account id');
        System.assertEquals('{"error":"Internal Server Error"}', invoices.error, 'Wrong error message');
    }

    @IsTest
    static void testGetInvoicesStaticSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","number":"123","items":[]}]}');

        mockService
            .when('getInvoices')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices.InvoiceList invoices = PortalCommerceApiInvoices.getInvoicesStatic('FI', 'INV_GRP', 10, null);
        Test.stopTest();

        System.debug('INVOICES = ' + invoices);
        System.assertNotEquals(null, invoices, 'Invoices should not be null');
        System.assertEquals(1, invoices.data.size(), 'Should have one invoice');
        System.assertEquals('123', invoices.data[0].invoiceNumber, 'Wrong invoice number');
        System.assertEquals('123456', invoices.data[0].id, 'Wrong invoice number');
    }
}