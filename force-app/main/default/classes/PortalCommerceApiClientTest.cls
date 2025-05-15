/**
 * Created by peterfriberg on 2024-09-24.
 */

@IsTest
private class PortalCommerceApiClientTest {

    @IsTest
    static void testGetSingletonInstance() {
        PortalCommerceApiClient instance1 = PortalCommerceApiClient.getInstance();
        PortalCommerceApiClient instance2 = PortalCommerceApiClient.getInstance();
        System.assertEquals(instance1, instance2, 'Instances are not the same');
    }

    @IsTest
    static void testGetOfferings() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        String endPoint = PortalCommerceApiClient.OFFERINGS_ENDPOINT.replace('{{PRODUCT_ID}}', 'IG_ID1');
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(endPoint, '{"values": []}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getOfferings('SE', 'IG_ID1', 5, 'NEXT_ID1');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"values": []}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(endPoint), 'Wrong endpoint');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('page-size=5'), 'Wrong pageSize');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('start-id=NEXT_ID1'), 'Wrong nextId');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('callout:Eficode_Office_SE'), 'Wrong office');
    }

    @IsTest
    static void testGetProducts() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.PRODUCTS_ENDPOINT, '{"values": []}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getProducts('FI', 'IG_ID', 10, 'NEXT_ID');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"values": []}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.PRODUCTS_ENDPOINT), 'Wrong endpoint');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('page-size=10'), 'Wrong pageSize');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('invoice-group=IG_ID'), 'Wrong invoiceGroupId');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('start-id=NEXT_ID'), 'Wrong nextId');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('callout:Eficode_Office_FI'), 'Wrong office');
    }

    @IsTest
    static void testGetQuotes() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        Test.startTest();
        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.QUOTES_ENDPOINT, '{"data": []}');
        Test.setMock(HttpCalloutMock.class, mock);

        HttpResponse resp = instance.getQuotes('FI', 'IG_ID', 10, null);
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"data": []}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.QUOTES_ENDPOINT), 'Wrong endpoint');
    }

    @IsTest
    static void testGetQuote() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.QUOTE_ENDPOINT, '{"id": "Q_ID"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getQuote('FI', 'Q_ID');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"id": "Q_ID"}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.QUOTE_ENDPOINT), 'Wrong endpoint');
    }

    @IsTest
    static void testGetQuotePdf() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        String endPoint = PortalCommerceApiClient.QUOTE_PDF_ENDPOINT.replace('{{QUOTE_ID}}', 'Q_ID');
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(endPoint, '');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getQuotePdf('FI', 'Q_ID');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(endPoint), 'Wrong endpoint');
    }

    @IsTest
    static void testGetInvoices() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICES_ENDPOINT, '{"data": []}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getInvoices('FI', 'IG_ID', 10, null);
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"data": []}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.INVOICES_ENDPOINT), 'Wrong endpoint');
    }

    @IsTest
    static void getPaidInvoices() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICES_ENDPOINT, '{"data": []}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getPaidInvoices('FI', 'IG_ID', 10, null);
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"data": []}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.INVOICES_ENDPOINT), 'Wrong endpoint');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('callout:Eficode_Office_FI'), 'Wrong office');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('page-size=10'), 'Wrong pageSize');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('invoice-group=IG_ID'), 'Wrong invoiceGroupId');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('status=PAID'), 'Wrong nextId');
    }

    @IsTest
    static void testGetInvoice() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICES_ENDPOINT, '{"id": "INV_ID"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getInvoice('FI', 'INV_ID');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"id": "INV_ID"}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.INVOICES_ENDPOINT), 'Wrong endpoint');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('callout:Eficode_Office_FI'), 'Wrong office');
    }

    @IsTest
    static void testgetInvoicePdf() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        String endPoint = PortalCommerceApiClient.INVOICE_PDF_ENDPOINT.replace('{{INVOICE_ID}}', 'INV_ID');
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(endPoint, '');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getInvoicePdf('UK', 'INV_ID');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(endPoint), 'Wrong endpoint');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('callout:Eficode_Office_UK'), 'Wrong office');
    }

    @IsTest
    static void getOrder() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.ORDER_ENDPOINT, '{"id": "ORDER_ID"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getOrder('FI', 'ORDER_ID');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"id": "ORDER_ID"}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.ORDER_ENDPOINT), 'Wrong endpoint');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('callout:Eficode_Office_FI'), 'Wrong office');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('/ORDER_ID'), 'Wrong orderId');
    }

    @IsTest
    static void testGetOrderPreview() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.ORDER_PREVIEW_ENDPOINT, '{"id": "ORDER_ID"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getOrderPreview('FI', '{"id": "ORDER_ID"}');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"id": "ORDER_ID"}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.ORDER_PREVIEW_ENDPOINT), 'Wrong endpoint');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('callout:Eficode_Office_FI'), 'Wrong office');
        System.assert(mock.getRequests()[0].getMethod().containsIgnoreCase('POST'), 'Wrong opration');
    }

    @IsTest
    static void testGetInvoiceGroups() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT, '{"data": []}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getInvoiceGroups('FI', 10, null);
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"data": []}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.INVOICE_GROUPS_ENDPOINT), 'Wrong endpoint');
    }

    @IsTest
    static void testGetEntitlementDisplayInfo() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.ENTITLEMENT_DISPLAY_INFO_ENDPOINT.replace('{{ENTITLEMENT_ID}}', 'ENT_ID'), '{"entitlementId": "ENT_ID"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getEntitlementDisplayInfo('FI', 'ENT_ID');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"entitlementId": "ENT_ID"}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.ENTITLEMENT_DISPLAY_INFO_ENDPOINT.replace('{{ENTITLEMENT_ID}}', 'ENT_ID')), 'Wrong endpoint');
    }

    @IsTest
    static void testGetEntitlementDetails() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.ENTITLEMENT_DETAILS_ENDPOINT.replace('{{ENTITLEMENT_ID}}', 'ENT_ID'), '{"entitlementId": "ENT_ID"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getEntitlementDetails('FI', 'ENT_ID');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('{"entitlementId": "ENT_ID"}', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.ENTITLEMENT_DETAILS_ENDPOINT.replace('{{ENTITLEMENT_ID}}', 'ENT_ID')), 'Wrong endpoint');
    }

    @IsTest
    static void testGenerateEndpointAllParameters() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();
        String endpoint = instance.generateEndpoint('FI', 'ENDPOINT', 10, 'NEXT_ID', 'IG_ID');
        System.assertEquals(true, endpoint.startsWithIgnoreCase(PortalCommerceApiClient.COMMERCE_API.replace('{{NAMED_CREDENTIAL}}', 'Eficode_Office_FI')), 'Wrong endpoint');
        System.assert(endpoint.containsIgnoreCase('page-size=10'), 'Wrong pageSize');
        System.assert(endpoint.containsIgnoreCase('invoice-group=IG_ID'), 'Wrong invoiceGroupId');
        System.assert(endpoint.containsIgnoreCase('start-id=NEXT_ID'), 'Wrong nextId');
        System.assert(endpoint.containsIgnoreCase('callout:Eficode_Office_FI'), 'Wrong office');
    }

    @IsTest
    static void testGenerateEndpointNoParameters() {
        // Override the office access check based on custom permissions to always allow access
        PortalCommerceApiAccessMgmt.allowOfficeAccessOverride = true;

        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();
        String endpoint = instance.generateEndpoint('FI', 'ENDPOINT', null, null, null);
        System.assertEquals(true, endpoint.startsWithIgnoreCase(PortalCommerceApiClient.COMMERCE_API.replace('{{NAMED_CREDENTIAL}}', 'Eficode_Office_FI')), 'Wrong endpoint');
        System.assert(!endpoint.containsIgnoreCase('page-size='), 'Wrong pageSize');
        System.assert(!endpoint.containsIgnoreCase('invoice-group='), 'Wrong invoiceGroupId');
        System.assert(!endpoint.containsIgnoreCase('start-id='), 'Wrong nextId');
        System.assert(endpoint.containsIgnoreCase('callout:Eficode_Office_FI'), 'Wrong office');
    }

    @IsTest
    static void testCreateRequestHeaderExists() {
        Test.startTest();
        HttpRequest req = PortalCommerceApiClient.createRequestHeader(true);
        Test.stopTest();

        System.assertEquals('*/*', req.getHeader('Accept'), 'Wrong Accept header');
        System.assertEquals('Bearer {!$Credential.Password}' , req.getHeader('Authorization'), 'Wrong Authorization header');
        System.assertEquals('{!$Credential.Username}', req.getHeader('X-transaction-account'), 'Wrong X-transaction-account header');
    }

    @IsTest
    static void testCreateRequestHeaderNotExists() {
        Test.startTest();
        HttpRequest req = PortalCommerceApiClient.createRequestHeader(false);
        Test.stopTest();

        System.assertEquals('*/*', req.getHeader('Accept'), 'Wrong Accept header');
        System.assertEquals('Bearer {!$Credential.Password}' , req.getHeader('Authorization'), 'Wrong Authorization header');
        System.assertEquals(null, req.getHeader('X-transaction-account'), 'Wrong X-transaction-account header');
    }

    @IsTest
    static void testGenerateEndpointThrowsExceptionNoAccess() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User u = new User(Alias = 'standt', Email='standarduser' + (Math.random() * 10000000) + '@testorg.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id, TimeZoneSidKey='America/Los_Angeles',
            Username='standarduser' + (Math.random() * 10000000) + '@testorg.com');
        insert u;

        // Step 2: Ensure the user does not have the custom permission
        System.runAs(u) {
            PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();
            // Create a new user that does not have the custom permission to use the FI office
            // then call the generateEndpoint method with the FI office

            try {
                instance.generateEndpoint('FI', 'ENDPOINT', null, null, null);
                System.assert(false, 'Exception not thrown');
            }
            catch (PortalCommerceApiClient.PortalCommerceApiException e) {
                System.assertEquals('User does not have access to the office: FI', e.getMessage(), 'Wrong exception message');
            }
        }
    }

    @IsTest
    static void testGenerateEndpointThrowsExceptionMissingOffice() {
        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();
        try {
            instance.generateEndpoint('MISSING', 'ENDPOINT', null, null, null);
            System.assert(false, 'Exception not thrown');
        }
        catch (PortalCommerceApiClient.PortalCommerceApiException e) {
            System.assertEquals('Named Credential does not exist for the office: MISSING', e.getMessage(), 'Wrong exception message');
        }
    }
}