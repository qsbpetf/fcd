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

    @IsTest
    static void testGetPaidInvoicesSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","number":"123","status":"PAID","items":[]}]}');

        mockService
            .when('getPaidInvoices')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        PortalCommerceApiInvoices.InvoiceList invoices = instance.getPaidInvoices('FI', 'INV_GRP', 10, null);
        Test.stopTest();

        System.assertNotEquals(null, invoices, 'Invoices should not be null');
        System.assertEquals(1, invoices.data.size(), 'Should have one invoice');
        System.assertEquals('123', invoices.data[0].invoiceNumber, 'Wrong invoice number');
        System.assertEquals('123456', invoices.data[0].id, 'Wrong invoice id');
        System.assertEquals('PAID', invoices.data[0].status, 'Wrong invoice status');
    }

    @IsTest
    static void testGetPaidInvoicesNot200Ok() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setStatus('Internal Server Error');
        response.setBody('{"error":"Internal Server Error"}');

        mockService
            .when('getPaidInvoices')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        PortalCommerceApiInvoices.InvoiceList invoices = instance.getPaidInvoices('FI', 'INV_GRP', 10, null);
        Test.stopTest();

        System.assertNotEquals(null, invoices, 'Invoices should not be null');
        System.assertEquals(true, invoices.missingAccountId, 'Should have missing account id');
        System.assertEquals('{"error":"Internal Server Error"}', invoices.error, 'Wrong error message');
    }

    @IsTest
    static void testGetPaidInvoicesStaticSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","number":"123","status":"PAID","items":[]}]}');

        mockService
            .when('getPaidInvoices')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices.InvoiceList invoices = PortalCommerceApiInvoices.getPaidInvoicesStatic('FI', 'INV_GRP', 10, null);
        Test.stopTest();

        System.assertNotEquals(null, invoices, 'Invoices should not be null');
        System.assertEquals(1, invoices.data.size(), 'Should have one invoice');
        System.assertEquals('123', invoices.data[0].invoiceNumber, 'Wrong invoice number');
        System.assertEquals('123456', invoices.data[0].id, 'Wrong invoice id');
        System.assertEquals('PAID', invoices.data[0].status, 'Wrong invoice status');
    }

    @IsTest
    static void testGetInvoiceSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"id":"123456","number":"123","status":"PAID","items":[{"id":"item1","description":"Test Item"}]}');

        mockService
            .when('getInvoice')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        PortalCommerceApiInvoices.InvoiceInfo invoice = instance.getInvoice('FI', '123456');
        Test.stopTest();

        System.assertNotEquals(null, invoice, 'Invoice should not be null');
        System.assertEquals('123', invoice.invoiceNumber, 'Wrong invoice number');
        System.assertEquals('123456', invoice.id, 'Wrong invoice id');
        System.assertEquals('PAID', invoice.status, 'Wrong invoice status');
        System.assertEquals(1, invoice.items.size(), 'Should have one item');
        System.assertEquals('item1', invoice.items[0].id, 'Wrong item id');
        System.assertEquals('Test Item', invoice.items[0].description, 'Wrong item description');
    }

    @IsTest
    static void testGetInvoiceNotFound() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(404);
        response.setStatus('Not Found');
        response.setBody('{"error":"Invoice not found"}');

        mockService
            .when('getInvoice')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        PortalCommerceApiInvoices.InvoiceInfo invoice = instance.getInvoice('FI', '123456');
        Test.stopTest();

        System.assertEquals(null, invoice, 'Invoice should be null when not found');
    }

    @IsTest
    static void testGetInvoicePdfSuccessful() {
        // Create a blob for the PDF content
        Blob pdfBlob = Blob.valueOf('Sample PDF Content');

        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBodyAsBlob(pdfBlob);

        mockService
            .when('getInvoicePdf')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        String pdfBase64 = instance.getInvoicePdf('FI', '123456');
        Test.stopTest();

        System.assertNotEquals(null, pdfBase64, 'PDF Base64 should not be null');
        System.assertEquals(EncodingUtil.base64Encode(pdfBlob), pdfBase64, 'PDF content does not match');
    }

    @IsTest
    static void testGetInvoicePdfNotFound() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(404);
        response.setStatus('Not Found');
        response.setBody('{"error":"Invoice PDF not found"}');

        mockService
            .when('getInvoicePdf')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        String result = instance.getInvoicePdf('FI', '123456');
        Test.stopTest();

        System.assertEquals('{"error":"Invoice PDF not found"}', result, 'Should return error message when PDF not found');
    }
}