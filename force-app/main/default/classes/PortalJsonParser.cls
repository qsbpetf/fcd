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
        orderInfo.technicalContact = getTechnicalContact(technicalContact);
        orderInfo.totalExTax = (Double) orderData.get('totalExTax');
        String dateString = (String) orderData.get('dueDate');
        dateString = String.isNotBlank(dateString) ? dateString.replace('T', ' ') : dateString;
        orderInfo.dueDate =String.isNotBlank(dateString) ? Datetime.valueOf(dateString.substring(0, dateString.length() - 5)).date() : null;
    }

    @TestVisible
    private static TechnicalContactDetails getTechnicalContact(Map<String, Object> technicalContact) {
        TechnicalContactDetails techCon = new TechnicalContactDetails();
        techCon.email = (String) technicalContact.get('email');
        techCon.firstName = (String) technicalContact.get('firstName');
        techCon.lastName = (String) technicalContact.get('lastName');
        techCon.phone = (String) technicalContact.get('phone');
        techCon.taxId = (String) technicalContact.get('taxId');
        techCon.companyName = (String) technicalContact.get('companyName');
        System.debug('== GOT: ' + techCon);
        Map<String, Object> address = (Map<String, Object>) technicalContact.get('address');
        techCon.address = getAddress(address);
        return techCon;
    }

    @TestVisible
    private static ContactAddress getAddress(Map<String, Object> address) {
        ContactAddress conAddr = new ContactAddress();
        conAddr.address1 = (String) address.get('address1');
        conAddr.address2 = (String) address.get('address2');
        conAddr.city = (String) address.get('city');
        conAddr.postalCode = (String) address.get('postalCode');
        conAddr.state = (String) address.get('state');
        conAddr.country = (String) address.get('country');
        System.debug('== GOT: ' + conAddr);
        return conAddr;
    }

    @TestVisible
    private static void getOrderItemData(OrderLine orderLine, Map<String, Object> itemData) {
        orderLine.productName = (String) itemData.get('productName');
        String startDateString = (String) itemData.get('startDate');
        startDateString = String.isNotBlank(startDateString) ? startDateString.replace('T', ' ') : startDateString;
        orderLine.startDate = String.isNotBlank(startDateString) ? Datetime.valueOf(startDateString).date() : null;
        String endDateString = (String) itemData.get('endDate');
        endDateString = String.isNotBlank(endDateString) ? endDateString.replace('T', ' ') : endDateString;
        orderLine.endDate = String.isNotBlank(endDateString) ? Datetime.valueOf(endDateString).date() : null;
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
        orderLine.edition = (String) itemData.get('edition');
        orderLine.platform = (String) itemData.get('platform');
        orderLine.maintenanceMonths = (Integer) itemData.get('maintenanceMonths');
        List<Object> discounts = (List<Object>) itemData.get('discounts');
        if (discounts != null && discounts.size() > 0) {
            Map<String, Object> discount = (Map<String, Object>) discounts.get(0);
            orderLine.discountReason = (String) discount.get('reason');
        }

        // Special handling of dates
        if (orderLine.saleType == 'NEW') {
            if (orderLine.startDate == null) {
                orderLine.startDate = Date.today();
                orderLine.endDate = Date.today().addMonths(
                    (itemData.get('maintenanceMonths') != null)
                        ? orderLine.maintenanceMonths
                        : 12)
                    .addDays(-1);
            }
        }

        System.debug(JSON.serializePretty(orderLine));
    }

    public class OrderLine {
        @AuraEnabled public String productName;
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String description;
        @AuraEnabled public String cloudSiteHostname;
        @AuraEnabled public String supportEntitlementNumber;
        @AuraEnabled public String entitlementNumber;
        @AuraEnabled public String saleType;
        @AuraEnabled public Double unitPrice;
        @AuraEnabled public Double total;
        @AuraEnabled public Integer unitCount;
        @AuraEnabled public Double priceAdjustment;
        @AuraEnabled public Double upgradeCredit;
        @AuraEnabled public Double partnerDiscountTotal;
        @AuraEnabled public Double loyaltyDiscountTotal;
        @AuraEnabled public String edition;
        @AuraEnabled public String platform;
        @AuraEnabled public Integer maintenanceMonths;
        @AuraEnabled public String discountReason;
    }

    public class ContactAddress {
        @AuraEnabled public String address1;
        @AuraEnabled public String address2;
        @AuraEnabled public String city;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String state;
        @AuraEnabled public String country;
    }

    public class TechnicalContactDetails {
        @AuraEnabled public String email;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String phone;
        @AuraEnabled public String taxId;
        @AuraEnabled public String companyName;
        @AuraEnabled public ContactAddress address;
    }

    public class OrderInformation {
        @AuraEnabled public String orderNumber;
        @AuraEnabled public TechnicalContactDetails technicalContact;
        @AuraEnabled public Double totalExTax;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public List<OrderLine> orderItems;

        public OrderInformation() {
            orderItems = new List<OrderLine>();
        }
    }
}