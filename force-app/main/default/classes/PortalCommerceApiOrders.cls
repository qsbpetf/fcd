/**
 * Created by peterfriberg on 2024-10-25.
 */

public with sharing class PortalCommerceApiOrders {

    @TestVisible static private PortalCommerceApiOrders instance;
    @TestVisible static private PortalCommerceApiClient client;

    static public PortalCommerceApiOrders getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiOrders();
            client = PortalCommerceApiClient.getInstance();
        }
        return instance;
    }

    public static void setApiClient(PortalCommerceApiClient apiClient) {
        client = apiClient;
    }

    public OrderInfo getOrder(String office, String quoteId) {
        HttpResponse response = client.getOrder(office, quoteId);
        if (response.getStatusCode() != 200) {
            OrderInfo theOrder = new OrderInfo();
            theOrder.error = response.getBody();
            theOrder.missingAccountId = true;
            return theOrder;
        }
        OrderInfo theOrder = (OrderInfo) JSON.deserialize(
            response.getBody()
                .replaceAll('"number"', '"quoteNumber"')
                .replaceAll('"currency"', '"isoCurrency"'),
            OrderInfo.class);
        System.debug('QUOTE = ' + response.getBody());
        return theOrder;
    }

    @AuraEnabled
    public static OrderInfo getOrderStatic(String office, String quoteId) {
        PortalCommerceApiOrders instance = PortalCommerceApiOrders.getInstance();
        return instance.getOrder(office, quoteId);
    }

    public OrderInfo getOrderPreview(String office, String quoteId, Integer quoteVersion) {
        String body =
            '{\n' +
            '    "source": "QUOTE",\n' +
            '    "quote": {\n' +
            '        "id": "{{QUOTE_ID}}",\n' +
            '        "version": {{VERSION}}\n' +
            '    }\n' +
            '}';
        body = body
            .replace('{{QUOTE_ID}}', quoteId)
            .replace('{{VERSION}}', String.valueOf(quoteVersion));
        HttpResponse response = client.getOrderPreview(office, body);
        if (response.getStatusCode() != 200) {
            OrderInfo theOrder = new OrderInfo();
            theOrder.error = response.getBody();
            theOrder.missingAccountId = true;
            return theOrder;
        }
        OrderInfo theOrder = (OrderInfo) JSON.deserialize(
            response.getBody()
                .replaceAll('"number"', '"quoteNumber"')
                .replaceAll('"currency"', '"isoCurrency"'),
            OrderInfo.class);
        System.debug('QUOTE = ' + response.getBody());
        return theOrder;
    }

    @AuraEnabled
    public static OrderInfo getOrderPreviewStatic(String office, String quoteId, Integer quoteVersion) {
        PortalCommerceApiOrders instance = PortalCommerceApiOrders.getInstance();
        return instance.getOrderPreview(office, quoteId, quoteVersion);
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class OrderInfo {
        @AuraEnabled public String orderId;
        @AuraEnabled public String slug;
        @AuraEnabled public String transactionAccountId;
        @AuraEnabled public List<OrderItem> items;
        @AuraEnabled public String error;
        @AuraEnabled public Boolean missingAccountId;
        @AuraEnabled public String office;
    }

    public class OrderItem {
        @AuraEnabled public String orderItemId;
        @AuraEnabled public QuoteLineItemDetailsReferenceType quoteLineItemDetailsReference;
        @AuraEnabled public ProcessingInfoType processingInfo;
    }

    public class ProcessingInfoType {
        @AuraEnabled public String status;
        @AuraEnabled public String saleTransitionType;
    }

    public class QuoteLineItemDetailsReferenceType {
        @AuraEnabled public String quoteLineItemId;
        @AuraEnabled public String quoteLineItemVersion;
    }
}