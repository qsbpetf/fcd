/**
 * Created by peterfriberg on 2024-09-24.
 */

@IsTest
private class PortalCommerceApiEntitlementsTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        // PortalCommerceApiQuotes.client = mockServiceStub;
        PortalCommerceApiEntitlements.instance = new PortalCommerceApiEntitlements();
        PortalCommerceApiEntitlements.setApiClient(mockServiceStub);
    }

    @IsTest
    static void testGetInstance() {
        PortalCommerceApiEntitlements.instance = null;
        PortalCommerceApiEntitlements instance = PortalCommerceApiEntitlements.getInstance();
        System.assertNotEquals(null, instance, 'Instance should not be null');
        System.assertNotEquals(null, PortalCommerceApiEntitlements.client, 'Client should not be null');
    }

    @IsTest
    static void testGetEntitlementDisplayInfoSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"entitlementId":"123456", "provisionedResource":{"name":"Resource 1", "ari":"123"}}');

        mockService
            .when('getEntitlementDisplayInfo')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiEntitlements instance = PortalCommerceApiEntitlements.getInstance();
        PortalCommerceApiEntitlements.EntitlementDisplayInfo entitlementDisplayInfo = instance.getEntitlementDisplayInfo('FI', '123456');
        Test.stopTest();

        System.debug('ENTITLEMENT DISPLAY INFO = ' + entitlementDisplayInfo);
        System.assertNotEquals(null, entitlementDisplayInfo, 'Entitlement Display Info should not be null');
        System.assertEquals('123456', entitlementDisplayInfo.entitlementId, 'Wrong entitlement id');
        System.assertEquals('Resource 1', entitlementDisplayInfo.provisionedResource.name, 'Wrong resource name');
        System.assertEquals('123', entitlementDisplayInfo.provisionedResource.ari, 'Wrong resource ari');
    }

    @IsTest
    static void testGetEntitlementDisplayInfoNot200Ok() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setStatus('Internal Server Error');
        response.setBody('{"error":"Internal Server Error"}');

        mockService
            .when('getEntitlementDisplayInfo')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiEntitlements instance = PortalCommerceApiEntitlements.getInstance();
        PortalCommerceApiEntitlements.EntitlementDisplayInfo entitlementDisplayInfo = instance.getEntitlementDisplayInfo('FI', '123456');
        Test.stopTest();

        System.debug('ENTITLEMENT DISPLAY INFO = ' + entitlementDisplayInfo);
        System.assertNotEquals(null, entitlementDisplayInfo, 'Entitlement Display Info should not be null');
        System.assertEquals('{"error":"Internal Server Error"}', entitlementDisplayInfo.error, 'Wrong error message');
    }

    @IsTest
    static void testGetEntitlementDisplayInfoStaticSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"entitlementId":"123456", "provisionedResource":{"name":"Resource 1", "ari":"123"}}');

        mockService
            .when('getEntitlementDisplayInfo')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiEntitlements.EntitlementDisplayInfo entitlementDisplayInfo = PortalCommerceApiEntitlements.getEntitlementDisplayInfoStatic('FI', '123456');
        Test.stopTest();

        System.debug('ENTITLEMENT DISPLAY INFO = ' + entitlementDisplayInfo);
        System.assertNotEquals(null, entitlementDisplayInfo, 'Entitlement Display Info should not be null');
        System.assertEquals('123456', entitlementDisplayInfo.entitlementId, 'Wrong entitlement id');
        System.assertEquals('Resource 1', entitlementDisplayInfo.provisionedResource.name, 'Wrong resource name');
        System.assertEquals('123', entitlementDisplayInfo.provisionedResource.ari, 'Wrong resource ari');
    }

    @IsTest
    static void testGetEntitlementDetailsSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"entitlementId":"123456","status":"ACTIVE","slug":"SLUG"}');

        mockService
            .when('getEntitlementDetails')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiEntitlements instance = PortalCommerceApiEntitlements.getInstance();
        PortalCommerceApiEntitlements.EntitlementDetails entitlementDetails = instance.getEntitlementDetails('FI', '123456');
        Test.stopTest();

        System.debug('ENTITLEMENT DETAILS = ' + entitlementDetails);
        System.assertNotEquals(null, entitlementDetails, 'Entitlement Details should not be null');
        System.assertEquals('123456', entitlementDetails.entitlementId, 'Wrong entitlement id');
        System.assertEquals('ACTIVE', entitlementDetails.status, 'Wrong status');
        System.assertEquals('SLUG', entitlementDetails.slug, 'Wrong slug');
    }

    @IsTest
    static void testGetEntitlementDetailsNot200Ok() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setStatus('Internal Server Error');
        response.setBody('{"error":"Internal Server Error"}');

        mockService
            .when('getEntitlementDetails')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiEntitlements instance = PortalCommerceApiEntitlements.getInstance();
        PortalCommerceApiEntitlements.EntitlementDetails entitlementDetails = instance.getEntitlementDetails('FI', '123456');
        Test.stopTest();

        System.debug('ENTITLEMENT DETAILS = ' + entitlementDetails);
        System.assertNotEquals(null, entitlementDetails, 'Entitlement Details should not be null');
        System.assertEquals('{"error":"Internal Server Error"}', entitlementDetails.error, 'Wrong error message');
    }

    @IsTest
    static void testGetEntitlementDetailsStaticSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"entitlementId":"123456","status":"ACTIVE","slug":"SLUG"}');

        mockService
            .when('getEntitlementDetails')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiEntitlements.EntitlementDetails entitlementDetails = PortalCommerceApiEntitlements.getEntitlementDetailsStatic('FI', '123456');
        Test.stopTest();

        System.debug('ENTITLEMENT DETAILS = ' + entitlementDetails);
        System.assertNotEquals(null, entitlementDetails, 'Entitlement Details should not be null');
        System.assertEquals('123456', entitlementDetails.entitlementId, 'Wrong entitlement id');
        System.assertEquals('ACTIVE', entitlementDetails.status, 'Wrong status');
        System.assertEquals('SLUG', entitlementDetails.slug, 'Wrong slug');
    }
}