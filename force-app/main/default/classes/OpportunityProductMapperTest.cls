/**
 * Created by peterfriberg on 2024-06-26.
 */

@IsTest
private class OpportunityProductMapperTest {

    @IsTest
    static void testConversion() {
        Test.startTest();
        Double result1 = OpportunityProductMapper.convertCurrency((Double) 100.0, (Double) 2.0);
        Double result2 = OpportunityProductMapper.convertCurrency(null, (Double) 1.0);
        Test.stopTest();

        System.assertEquals(200.0, result1, 'Conversion failed');
        System.assertEquals(null, result2, 'Conversion failed');
    }

    @IsTest
    static void testMapOpportunityLineItem() {
        // Setup test data
        Account acc = new Account(Name = 'Test', CurrencyIsoCode = 'USD');
        insert acc;

        Opportunity opp = new Opportunity(Name = 'Test', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = acc.Id, Pricebook2Id = Test.getStandardPricebookId(), CurrencyIsoCode = 'USD');
        insert opp;

        Product2 prod = new Product2(Name = 'Product Test', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id, UnitPrice = 100.00, IsActive = true, CurrencyIsoCode = 'USD');
        insert pbe;

        PortalJsonParser.OrderLine orderLine = new PortalJsonParser.OrderLine();
        orderLine.productName = 'Test Product';
        orderLine.unitPrice = 1000.00;
        orderLine.startDate = Date.today();
        orderLine.endDate = Date.today().addMonths(1);
        orderLine.description = 'Test Description';
        orderLine.cloudSiteHostname = 'Testhostname';
        orderLine.supportEntitlementNumber = '123456';
        orderLine.entitlementNumber = '123456';
        orderLine.saleType = 'NEW';
        orderLine.discountReason = '';
        orderLine.total = 5000;
        orderLine.unitCount = 50;
        orderLine.priceAdjustment = 60;
        orderLine.upgradeCredit = 70;
        orderLine.partnerDiscountTotal = 80;
        orderLine.loyaltyDiscountTotal = 90;

        Double conversionFactor = 1.00;

        Test.startTest();
        OpportunityProductMapper oppProdMapper = OpportunityProductMapper.getInstance();
        OpportunityLineItem oli = oppProdMapper.mapOpportunityLineItem(pbe, opp.Id, orderLine, conversionFactor);
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, oli, 'OpportunityLineItem should not be null');
        System.assertEquals(opp.Id, oli.OpportunityId);
        System.assertEquals(pbe.Id, oli.PricebookEntryId);
        System.assertEquals(pbe.Product2Id, oli.Product2Id);
        System.assertEquals(orderLine.description, oli.Additional_Info__c);
        System.assertEquals(orderLine.cloudSiteHostname, oli.Cloud_Site_Name__c);
        System.assertEquals(orderLine.supportEntitlementNumber, oli.SEN__c);
        System.assertEquals(orderLine.entitlementNumber, oli.Entitlement_Number__c);
        System.assertEquals('New', oli.Renewal__c);
        System.assertEquals(orderLine.total, oli.Editable_Cost_Price_in_Dollars__c);
        System.assertEquals(orderLine.unitCount, oli.User_Count__c);
        System.assertEquals(orderLine.priceAdjustment, oli.Atlassian_Price_Adjustment__c);
        System.assertEquals(orderLine.upgradeCredit, oli.Atlassian_Upgrade_Credit__c);
        System.assertEquals(orderLine.partnerDiscountTotal, oli.Atlassian_Partner_Discount__c);
        System.assertEquals(orderLine.loyaltyDiscountTotal, oli.Atlassian_Loyalty_Discount__c);
        System.assertEquals(orderLine.productName, oli.QuoteOriginalProduct__c);
        System.assertEquals(1, oli.Quantity);
        System.assertEquals(orderLine.unitPrice - orderLine.upgradeCredit - orderLine.loyaltyDiscountTotal, oli.Editable_Unit_List_Price_in_USD__c);
    }

    @IsTest
    static void testMapOpportunityLineItemZeroNoLineReturned() {
        // Setup test data
        Account acc = new Account(Name = 'Test', CurrencyIsoCode = 'USD');
        insert acc;

        Opportunity opp = new Opportunity(Name = 'Test', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = acc.Id, Pricebook2Id = Test.getStandardPricebookId(), CurrencyIsoCode = 'USD');
        insert opp;

        Product2 prod = new Product2(Name = 'Product Test', IsActive = true);
        insert prod;

        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id, UnitPrice = 100.00, IsActive = true, CurrencyIsoCode = 'USD');
        insert pbe;

        PortalJsonParser.OrderLine orderLine = new PortalJsonParser.OrderLine();
        orderLine.unitPrice = 0.0;

        Double conversionFactor = 1.00;

        Test.startTest();
        OpportunityProductMapper oppProdMapper = OpportunityProductMapper.getInstance();
        OpportunityLineItem oli = oppProdMapper.mapOpportunityLineItem(pbe, opp.Id, orderLine, conversionFactor);
        Test.stopTest();

        // Verify results
        System.assertEquals(null, oli, 'OpportunityLineItem should be null');
    }
}