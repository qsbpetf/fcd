/**
 * Created by peterfriberg on 2024-10-16.
 */

@IsTest
private class PpcOpportunityProductMapperTest {


    @TestSetup
    static void setup() {
        // create default product
        String defaultProductName;
        Map<String, PpcProductToSalesforceMapping__mdt> rows = PpcProductToSalesforceMapping__mdt.getAll();
        for (PpcProductToSalesforceMapping__mdt row : rows.values()) {
            String prodName = row.ProductName__c;
            String salesforceProduct = row.SalesforceProductName__c;
            if (prodName == null) {
                defaultProductName = salesforceProduct;
                break;
            }
        }

        Product2 prod = TestDataFactory.getProduct();
        System.debug(prod);
        prod.Name = defaultProductName;
        insert prod;

        PricebookEntry pbe = TestDataFactory.getPbEntry(Test.getStandardPricebookId(), prod.Id, 'EUR');
        insert pbe;

        AtlassianOffering__c offering = new AtlassianOffering__c();
        offering.Name = 'Test Offering';
        offering.AtlassianId__c = '123';
        offering.Product__c = prod.Id;
        insert offering;
    }

    @IsTest
    static void getInstanceSuccessfully() {
        PpcOpportunityProductMapper instance = PpcOpportunityProductMapper.getInstance();
        System.assertNotEquals(null, instance);
    }

    @IsTest
    static void testMapProductsFromQuoteSuccessful() {
        PpcOpportunityProductMapper instance = PpcOpportunityProductMapper.getInstance();
        PortalCommerceApiQuotes.QuoteInfo quoteInfo = new PortalCommerceApiQuotes.QuoteInfo();
        quoteInfo.quoteNumber = '123';
        quoteInfo.upcomingBills = new PortalCommerceApiQuotes.BillItem();
        quoteInfo.upcomingBills.lines = new List<PortalCommerceApiQuotes.BillLineItem>();
        quoteInfo.upcomingBills.lines.add(new PortalCommerceApiQuotes.BillLineItem());
        quoteInfo.upcomingBills.lines[0].description = 'Use default product';
        quoteInfo.upcomingBills.lines[0].quantity = 50;
        quoteInfo.upcomingBills.lines[0].total = 100;
        quoteInfo.upcomingBills.lines[0].subTotal = 50;
        quoteInfo.upcomingBills.lines[0].offeringId = '123';
        quoteInfo.upcomingBills.lines.add(new PortalCommerceApiQuotes.BillLineItem());
        quoteInfo.upcomingBills.lines[1].description = 'Use default product';
        quoteInfo.upcomingBills.lines[1].quantity = 40;
        quoteInfo.upcomingBills.lines[1].total = -20;
        quoteInfo.upcomingBills.lines[1].subTotal = -10;
        quoteInfo.upcomingBills.lines[1].offeringId = '123';

        Account acc = TestDataFactory.getAccount('Finland', 'EUR');
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.Pricebook2Id = Test.getStandardPricebookId();
        insert opp;

        Double conversionFactor = 1.0;
        OpportunityProductMapper.LogData logData = new OpportunityProductMapper.LogData();

        Test.startTest();
        List<OpportunityLineItem> opportunityLineItemsAll = instance.mapProducts(quoteInfo, opp, conversionFactor, logData, false);
        List<OpportunityLineItem> opportunityLineItemsMerged = instance.mapProducts(quoteInfo, opp, conversionFactor, logData, true);
        Test.stopTest();

        System.assertEquals(2, opportunityLineItemsAll.size());
        System.assertEquals(1, opportunityLineItemsMerged.size());
    }

    @IsTest
    static void testMapProductsFromInvoiceSuccessful() {
        PpcOpportunityProductMapper instance = PpcOpportunityProductMapper.getInstance();
        PortalCommerceApiInvoices.InvoiceInfo invoiceInfo = new PortalCommerceApiInvoices.InvoiceInfo();
        invoiceInfo.invoiceNumber = '123';
        invoiceInfo.items = new List<PortalCommerceApiInvoices.InvoiceItem>();
        invoiceInfo.items.add(new PortalCommerceApiInvoices.InvoiceItem());
        invoiceInfo.items[0].description = 'Use default product';
        invoiceInfo.items[0].quantity = 50;
        invoiceInfo.items[0].total = 100;
        invoiceInfo.items[0].subTotal = 50;
        invoiceInfo.items.add(new PortalCommerceApiInvoices.InvoiceItem());
        invoiceInfo.items[1].description = 'Use default product';
        invoiceInfo.items[1].quantity = 40;
        invoiceInfo.items[1].total = -20;
        invoiceInfo.items[1].subTotal = -10;

        Account acc = TestDataFactory.getAccount('Finland', 'EUR');
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.Pricebook2Id = Test.getStandardPricebookId();
        insert opp;

        Double conversionFactor = 1.0;
        OpportunityProductMapper.LogData logData = new OpportunityProductMapper.LogData();

        Test.startTest();
        List<OpportunityLineItem> opportunityLineItemsAll = instance.mapProducts(invoiceInfo, opp, conversionFactor, logData, false);
        List<OpportunityLineItem> opportunityLineItemsMerged = instance.mapProducts(invoiceInfo, opp, conversionFactor, logData, true);
        Test.stopTest();

        System.assertEquals(2, opportunityLineItemsAll.size());
        System.assertEquals(1, opportunityLineItemsMerged.size());
    }
}