/**
 * Created by peterfriberg on 2024-11-11.
 */

@IsTest
private class PortalCommerceApiOrdersTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        // PortalCommerceApiQuotes.client = mockServiceStub;
        PortalCommerceApiOrders.instance = new PortalCommerceApiOrders();
        PortalCommerceApiOrders.setApiClient(mockServiceStub);
    }

    @IsTest
    static void testGetInstance() {
        PortalCommerceApiOrders.instance = null;
        PortalCommerceApiOrders instance = PortalCommerceApiOrders.getInstance();
        System.assertNotEquals(null, instance, 'Instance should not be null');
        System.assertNotEquals(null, PortalCommerceApiOrders.client, 'Client should not be null');
    }

    @IsTest
    static void testGetOrderSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"orderId":"123456", "items":[{"orderItemId":"1"}]}');

        mockService
            .when('getOrder')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiOrders instance = PortalCommerceApiOrders.getInstance();
        PortalCommerceApiOrders.OrderInfo order = instance.getOrder('FI', '123456');
        Test.stopTest();

        System.debug('ORDER = ' + order);
        System.assertNotEquals(null, order, 'Order should not be null');
        System.assertEquals('123456', order.orderId, 'Wrong quote number');
        System.assertEquals(1, order.items.size(), 'Should have one item');
        System.assertEquals('1', order.items[0].orderItemId, 'Wrong item number');
    }

    @IsTest
    static void testGetOrderStaticSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"orderId":"123456", "items":[{"orderItemId":"1"}]}');

        mockService
            .when('getOrder')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiOrders.OrderInfo order = PortalCommerceApiOrders.getOrderStatic('FI', '123456');
        Test.stopTest();

        System.debug('ORDER = ' + order);
        System.assertNotEquals(null, order, 'Order should not be null');
        System.assertEquals('123456', order.orderId, 'Wrong quote number');
        System.assertEquals(1, order.items.size(), 'Should have one item');
        System.assertEquals('1', order.items[0].orderItemId, 'Wrong item number');
    }

    @IsTest
    static void testGetOrdersFailed() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(400);
        response.setStatus('ERROR');
        response.setBody('{"error":"Bad Request"}');

        mockService
            .when('getOrder')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiOrders instance = PortalCommerceApiOrders.getInstance();
        PortalCommerceApiOrders.OrderInfo order = instance.getOrder('FI', '123456');
        Test.stopTest();

        System.debug('ORDER = ' + order);
        System.assertNotEquals(null, order, 'Order should not be null');
        System.assert(order.error.containsIgnoreCase('Bad Request'), 'Wrong error message');
        System.assert(order.missingAccountId, 'Should be missing account id');
    }

    @IsTest
    static void testGetOrederPreviewSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"orderId":"123456", "items":[{"orderItemId":"1"}]}');

        mockService
            .when('getOrderPreview')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiOrders instance = PortalCommerceApiOrders.getInstance();
        PortalCommerceApiOrders.OrderInfo order = instance.getOrderPreview('FI', '123456', 15);
        Test.stopTest();

        System.debug('ORDER = ' + order);
        System.assertNotEquals(null, order, 'Order should not be null');
        System.assertEquals('123456', order.orderId, 'Wrong quote number');
        System.assertEquals(1, order.items.size(), 'Should have one item');
        System.assertEquals('1', order.items[0].orderItemId, 'Wrong item number');
    }

    @IsTest
    static void testGetOrederPreviewFailed() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(400);
        response.setStatus('ERROR');
        response.setBody('{"error":"Bad Request"}');

        mockService
            .when('getOrderPreview')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiOrders instance = PortalCommerceApiOrders.getInstance();
        PortalCommerceApiOrders.OrderInfo order = instance.getOrderPreview('FI', '123456', 15);
        Test.stopTest();

        System.debug('ORDER = ' + order);
        System.assertNotEquals(null, order, 'Order should not be null');
        System.assert(order.error.containsIgnoreCase('Bad Request'), 'Wrong error message');
        System.assert(order.missingAccountId, 'Should be missing account id');
    }

    @IsTest
    static void testGetOrederPreviewStaticSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"orderId":"123456", "items":[{"orderItemId":"1"}]}');

        mockService
            .when('getOrderPreview')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiOrders.OrderInfo order = PortalCommerceApiOrders.getOrderPreviewStatic('FI', '123456', 15);
        Test.stopTest();

        System.debug('ORDER = ' + order);
        System.assertNotEquals(null, order, 'Order should not be null');
        System.assertEquals('123456', order.orderId, 'Wrong quote number');
        System.assertEquals(1, order.items.size(), 'Should have one item');
        System.assertEquals('1', order.items[0].orderItemId, 'Wrong item number');
    }
}