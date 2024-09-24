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
    static void testGetProducts() {
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
        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.QUOTES_ENDPOINT, '{"data": []}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
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
        PortalCommerceApiClient instance = PortalCommerceApiClient.getInstance();

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse(PortalCommerceApiClient.QUOTE_PDF_ENDPOINT.replace('{{QUOTE_ID}}', 'Q_ID'), '');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        HttpResponse resp = instance.getQuotePdf('FI', 'Q_ID');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals('', resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase(PortalCommerceApiClient.QUOTE_PDF_ENDPOINT.replace('{{QUOTE_ID}}', 'Q_ID')), 'Wrong endpoint');
    }

    @IsTest
    static void testGetInvoices() {
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
    static void testGetInvoiceGroups() {
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