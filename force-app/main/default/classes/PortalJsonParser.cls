/**
 * Created by peterfriberg on 2024-05-30.
 */

public with sharing class PortalJsonParser {

    private static PortalJsonParser instance;

    public static PortalJsonParser getInstance() {
        if (instance == null) {
            instance = new PortalJsonParser();
        }
        return instance;
    }

    public OrderInformation parseJson(String jsonText) {
        Map<String, Object> orderData = (Map<String, Object>) JSON.deserializeUntyped(jsonText);
        List<Object> orderItems = (List<Object>) orderData.get('orderItems');

        OrderInformation orderInfo = new OrderInformation();
        getOrderData(orderInfo, orderData);

        for (Object orderItem : orderItems) {
            Map<String, Object> itemData = (Map<String, Object>) orderItem;
            OrderLine orderLineData = new OrderLine();
            getOrderItemData(orderLineData, itemData);
            orderInfo.orderItems.add(orderLineData);
        }

        return orderInfo;
    }

    @TestVisible
    private static void getOrderData(OrderInformation orderInfo, Map<String, Object> orderData) {
        orderInfo.orderNumber = (String) orderData.get('orderNumber');
        Map<String, Object> technicalContact = (Map<String, Object>) orderData.get('technicalContact');
        orderInfo.technicalContactEmail = (String) technicalContact.get('email');
        orderInfo.totalExTax = (Double) orderData.get('totalExTax');
        String dateString = (String) orderData.get('dueDate');
        dateString = dateString.replace('T', ' ');
        orderInfo.dueDate = Datetime.valueOf(dateString.substring(0, dateString.length() - 5)).date();
    }

    // TODO: Add parsing of fields: edition, platform
    @TestVisible
    private static void getOrderItemData(OrderLine orderLine, Map<String, Object> itemData) {
        orderLine.productName = (String) itemData.get('productName');
        String startDateString = (String) itemData.get('startDate');
        startDateString = startDateString.replace('T', ' ');
        orderLine.startDate = Datetime.valueOf(startDateString).date();
        String endDateString = (String) itemData.get('endDate');
        endDateString = endDateString.replace('T', ' ');
        orderLine.endDate = Datetime.valueOf(endDateString).date();
        orderLine.description = (String) itemData.get('description');
        orderLine.cloudSiteHostname = (String) itemData.get('cloudSiteHostname');
        orderLine.supportEntitlementNumber = (String) itemData.get('supportEntitlementNumber');
        orderLine.entitlementNumber = (String) itemData.get('entitlementNumber');
        orderLine.saleType = (String) itemData.get('saleType');
        orderLine.unitPrice = (Double) itemData.get('unitPrice');
        orderLine.total = (Double) itemData.get('total');
        orderLine.unitCount = (Integer) itemData.get('unitCount');
        orderLine.priceAdjustment = (Double) itemData.get('priceAdjustment');
        orderLine.upgradeCredit = (Double) itemData.get('upgradeCredit');
        orderLine.partnerDiscountTotal = (Double) itemData.get('partnerDiscountTotal');
        orderLine.loyaltyDiscountTotal = (Double) itemData.get('loyaltyDiscountTotal');
    }

    // TODO: Add fields: edition, platform
    public class OrderLine {
        public String productName;
        public Date startDate;
        public Date endDate;
        public String description;
        public String cloudSiteHostname;
        public String supportEntitlementNumber;
        public String entitlementNumber;
        public String saleType;
        public Double unitPrice;
        public Double total;
        public Integer unitCount;
        public Double priceAdjustment;
        public Double upgradeCredit;
        public Double partnerDiscountTotal;
        public Double loyaltyDiscountTotal;
    }

    public class OrderInformation {
        public String orderNumber;
        public String technicalContactEmail;
        public Double totalExTax;
        public Date dueDate;
        public List<OrderLine> orderItems;

        public OrderInformation() {
            orderItems = new List<OrderLine>();
        }
    }
}