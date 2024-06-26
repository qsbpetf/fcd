/**
 * Created by peterfriberg on 2024-06-25.
 */

@IsTest
private class PortalJsonParserTest {

    private static final String FULL_JSON =
        '{\n' +
        '  "orderNumber" : "AT-315634773",\n' +
        '  "poNumber" : "123",\n' +
        '  "createdDate" : "2024-05-16T02:35:34.611-0500",\n' +
        '  "dueDate" : "2024-06-15T00:00:00.000-0500",\n' +
        '  "billingContact" : {\n' +
        '    "companyName" : "Eficode Finland",\n' +
        '    "firstName" : "Katja",\n' +
        '    "lastName" : "Loikkanen",\n' +
        '    "email" : "katja.loikkanen@eficode.com",\n' +
        '    "phone" : "+358405611299",\n' +
        '    "taxId" : "FI19718143",\n' +
        '    "address" : {\n' +
        '      "address1" : "Pohjoinen Rautatiekatu 25",\n' +
        '      "address2" : "",\n' +
        '      "city" : "Helsinki",\n' +
        '      "postalCode" : "00100",\n' +
        '      "state" : "Uusimaa",\n' +
        '      "country" : "Finland"\n' +
        '    }\n' +
        '  },\n' +
        '  "technicalContact" : {\n' +
        '    "companyName" : "Eficode",\n' +
        '    "firstName" : "Antti",\n' +
        '    "lastName" : "Päivinen",\n' +
        '    "email" : "antti.paivinen@eficode.com",\n' +
        '    "phone" : "358447736646",\n' +
        '    "taxId" : "",\n' +
        '    "address" : {\n' +
        '      "address1" : "Pohjoinen Rautatiekatu 25",\n' +
        '      "address2" : "",\n' +
        '      "city" : "Helsinki",\n' +
        '      "postalCode" : "00100",\n' +
        '      "state" : "Uusimaa",\n' +
        '      "country" : "Finland"\n' +
        '    }\n' +
        '  },\n' +
        '  "currency" : "USD",\n' +
        '  "partnerName" : "Eficode Finland",\n' +
        '  "orderItems" : [ {\n' +
        '    "productName" : "Bitbucket (Cloud)",\n' +
        '    "startDate" : "2024-05-03T00:00:00.000-0500",\n' +
        '    "endDate" : "2025-05-03T00:00:00.000-0500",\n' +
        '    "licensedTo" : "Eficode",\n' +
        '    "description" : "Bitbucket (Cloud) 50 Users (Annual Payments) Renewal",\n' +
        '    "edition" : "premium",\n' +
        '    "cloudSiteHostname" : "groke-tech",\n' +
        '    "supportEntitlementNumber" : "SEN-42318436",\n' +
        '    "entitlementNumber" : "E-3Z4-J85-263-SR4",\n' +
        '    "entitlementId" : "b692f44e-e01a-470d-b7cc-61c49f4ac015",\n' +
        '    "saleType" : "RENEWAL",\n' +
        '    "unitPrice" : 3000.00,\n' +
        '    "platform" : "CLOUD",\n' +
        '    "taxExempt" : false,\n' +
        '    "licenseType" : "COMMERCIAL",\n' +
        '    "unitCount" : 50,\n' +
        '    "isTrialPeriod" : false,\n' +
        '    "isUnlimitedUsers" : false,\n' +
        '    "maintenanceMonths" : 12,\n' +
        '    "priceAdjustment" : 300.00,\n' +
        '    "upgradeCredit" : 0.00,\n' +
        '    "partnerDiscountTotal" : 300.00,\n' +
        '    "loyaltyDiscountTotal" : 0,\n' +
        '    "discounts" : [ {\n' +
        '      "amount" : 300.00,\n' +
        '      "percentage" : 10.00,\n' +
        '      "reason" : "PARTNER_DISCOUNT",\n' +
        '      "type" : "EXPERT"\n' +
        '    } ],\n' +
        '    "total" : 2700.00\n' +
        '  }, \n' +
        '  {\n' +
        '    "productName" : "Bitbucket (Other)",\n' +
        '    "startDate" : null,\n' +
        '    "endDate" : null,\n' +
        '    "licensedTo" : "Eficode",\n' +
        '    "description" : "Bitbucket (Other) 50 Users (Annual Payments) New",\n' +
        '    "edition" : "premium",\n' +
        '    "cloudSiteHostname" : "groke-tech",\n' +
        '    "supportEntitlementNumber" : "SEN-42318436",\n' +
        '    "entitlementNumber" : "E-3Z4-J85-263-SR4",\n' +
        '    "entitlementId" : "b692f44e-e01a-470d-b7cc-61c49f4ac015",\n' +
        '    "saleType" : "NEW",\n' +
        '    "unitPrice" : 3000.00,\n' +
        '    "platform" : "CLOUD",\n' +
        '    "taxExempt" : false,\n' +
        '    "licenseType" : "COMMERCIAL",\n' +
        '    "unitCount" : 50,\n' +
        '    "isTrialPeriod" : false,\n' +
        '    "isUnlimitedUsers" : false,\n' +
        '    "maintenanceMonths" : 12,\n' +
        '    "priceAdjustment" : 300.00,\n' +
        '    "upgradeCredit" : 0.00,\n' +
        '    "partnerDiscountTotal" : 300.00,\n' +
        '    "loyaltyDiscountTotal" : 0,\n' +
        '    "discounts" : [ {\n' +
        '      "amount" : 300.00,\n' +
        '      "percentage" : 10.00,\n' +
        '      "reason" : "PARTNER_DISCOUNT",\n' +
        '      "type" : "EXPERT"\n' +
        '    } ],\n' +
        '    "total" : 2700.00\n' +
        '  } ],\n' +
        '  "totalExTax" : 2700.00,\n' +
        '  "totalIncTax" : 2700.00,\n' +
        '  "totalTax" : 0.00\n' +
        '}';

    @IsTest
    static void getInstance() {
        Test.startTest();
        PortalJsonParser parser1 = PortalJsonParser.getInstance();
        PortalJsonParser parser2 = PortalJsonParser.getInstance();
        Test.stopTest();

        System.assertNotEquals(null, parser1, 'Instance 1 should not be null');
        System.assertNotEquals(null, parser2, 'Instance 2 should not be null');
        System.assertEquals(parser1, parser2, 'Instances should be the same');
    }

    @IsTest
    static void parseEmptyJson() {
        Test.startTest();
        PortalJsonParser parser = PortalJsonParser.getInstance();
        String jsonText = '{}';
        PortalJsonParser.OrderInformation orderInfo = parser.parseJson(jsonText);
        Test.stopTest();

        System.assertNotEquals(null, orderInfo, 'OrderInfo should not be null');
        System.debug(JSON.serializePretty(orderInfo));
    }

    @IsTest
    static void parseFullJsonOk() {
        Test.startTest();
        PortalJsonParser parser = PortalJsonParser.getInstance();
        String jsonText = FULL_JSON;
        PortalJsonParser.OrderInformation orderInfo = parser.parseJson(jsonText);
        Test.stopTest();

        System.assertNotEquals(null, orderInfo, 'OrderInfo should not be null');
        System.debug(JSON.serializePretty(orderInfo));

        System.assertEquals('AT-315634773', orderInfo.orderNumber, 'Order number');
        System.assertEquals(Date.newInstance(2024, 06,15), orderInfo.dueDate, 'Due date');
        System.assertEquals('USD', orderInfo.isoCurrencyCode, 'Currency');
        System.assertEquals(2700.00, orderInfo.totalExTax, 'Total ex tax');

        PortalJsonParser.TechnicalContactDetails techCon = orderInfo.technicalContact;
        System.assertNotEquals(null, techCon, 'Technical contact should not be null');
        System.assertEquals('Eficode', techCon.companyName, 'Company name');
        System.assertEquals('Antti', techCon.firstName, 'First name');
        System.assertEquals('Päivinen', techCon.lastName, 'Last name');

        List<PortalJsonParser.OrderLine> orderItems = orderInfo.orderItems;
        System.assertNotEquals(null, orderItems, 'Order items should not be null');
        System.assertEquals(2, orderItems.size(), 'Order items size');

        PortalJsonParser.OrderLine orderLine1 = orderItems[0];
        System.assertNotEquals(null, orderLine1, 'Order line should not be null');
        System.assertEquals('Bitbucket (Cloud)', orderLine1.productName, 'Product name');
        System.assertEquals(Date.newInstance(2024, 05, 03), orderLine1.startDate, 'Start date');
        System.assertEquals(Date.newInstance(2025, 05, 03), orderLine1.endDate, 'End date');
        System.assertEquals('Bitbucket (Cloud) 50 Users (Annual Payments) Renewal', orderLine1.description, 'Description');
        System.assertEquals('premium', orderLine1.edition, 'Edition');
        System.assertEquals('groke-tech', orderLine1.cloudSiteHostname, 'Cloud site hostname');
        System.assertEquals('SEN-42318436', orderLine1.supportEntitlementNumber, 'Support entitlement number');
        System.assertEquals('E-3Z4-J85-263-SR4', orderLine1.entitlementNumber, 'Entitlement number');
        System.assertEquals('RENEWAL', orderLine1.saleType, 'Sale type');
        System.assertEquals(3000.00, orderLine1.unitPrice, 'Unit price');
        System.assertEquals(2700.00, orderLine1.total, 'Total');
        System.assertEquals(50, orderLine1.unitCount, 'Unit count');
        System.assertEquals(300.00, orderLine1.priceAdjustment, 'Price adjustment');
        System.assertEquals(0.00, orderLine1.upgradeCredit, 'Upgrade credit');
        System.assertEquals(300.00, orderLine1.partnerDiscountTotal, 'Partner discount total');
        System.assertEquals(0, orderLine1.loyaltyDiscountTotal, 'Loyalty discount total');
        System.assertEquals('CLOUD', orderLine1.platform, 'Platform');
        System.assertEquals(12, orderLine1.maintenanceMonths, 'Maintenance months');
        System.assertEquals('PARTNER_DISCOUNT', orderLine1.discountReason, 'Discount reason');

        PortalJsonParser.OrderLine orderLine2 = orderItems[1];
        System.assertNotEquals(null, orderLine2, 'Order line should not be null');
        System.assertEquals('Bitbucket (Other)', orderLine2.productName, 'Product name');
        System.assertEquals(Date.today(), orderLine2.startDate, 'Start date');
        System.assertEquals(Date.today().addMonths(12), orderLine2.endDate, 'End date');
        System.assertEquals('NEW', orderLine2.saleType, 'Sale type');
    }
}