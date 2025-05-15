/**
 * Created by peterfriberg on 2024-11-20.
 */

@IsTest
private class PpcQuoteConverterTest {

    private static final UniversalMocker mockService;
    private static final PpcOpportunityProductMapper mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PpcOpportunityProductMapper.class);
        mockServiceStub = (PpcOpportunityProductMapper) mockService.createStub();
        PpcOpportunityProductMapper.instance = mockServiceStub;
    }

    static void testSetup() {
        List<Buying_Exchange_Rate__c> currencyList = new List<Buying_Exchange_Rate__c>();
        currencyList.add(new Buying_Exchange_Rate__c(
            Exchange_Rate_from_USD_to_EUR__c = 1.0,
            Exchange_Rate_from_USD_to_GBP__c = 1.0,
            Start_Date__c = Date.today().addDays(-1)));
        insert currencyList;
    }

    @IsTest
    static void testUpdateOpportunitySuccessful() {
        testSetup();

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.CV_Subsidiary__c = 'FI';
        acc.BillingCountry = 'Finland';
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.Pricebook2Id = Test.getStandardPricebookId();
        insert opp;

        PortalCommerceApiQuotes.QuoteInfo quoteData = new PortalCommerceApiQuotes.QuoteInfo();
        quoteData.quoteNumber = '123';
        quoteData.upcomingBills = new PortalCommerceApiQuotes.BillItem();
        quoteData.upcomingBills.subTotal = 12345;
        quoteData.upcomingBills.lines = new List<PortalCommerceApiQuotes.BillLineItem>();
        quoteData.expiresAt = Datetime.now().addYears(1).getTime();

        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        log.productLog = new List<String>{'Test1'};
        log.pbeLog = new List<String>{'Test2'};
        PpcQuoteConverter.updateOpportunity(opp, quoteData, log);

        Opportunity updatedOpp = [SELECT Atlassian_AT_Quote_ref__c, Atlassian_AT_Quote_amount__c, AT_quote_expiry__c, PpcQuoteImportResult__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('123', updatedOpp.Atlassian_AT_Quote_ref__c, 'Atlassian_AT_Quote_ref__c should be updated');
        System.assertEquals(123.45, updatedOpp.Atlassian_AT_Quote_amount__c, 'Atlassian_AT_Quote_amount__c should be updated');
        System.assertEquals(Date.today().addYears(1), updatedOpp.AT_quote_expiry__c, 'AT_quote_expiry__c should be updated');
        System.assert(updatedOpp.PpcQuoteImportResult__c.containsIgnoreCase('Test1'), 'PpcQuoteImportResult__c should be updated');
        System.assert(updatedOpp.PpcQuoteImportResult__c.containsIgnoreCase('Test2'), 'PpcQuoteImportResult__c should be updated');
    }

    @IsTest
    static void testMapProductsSuccessful() {
        testSetup();

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.CV_Subsidiary__c = 'FI';
        acc.BillingCountry = 'Finland';
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        insert opp;

        PortalCommerceApiQuotes.QuoteInfo quoteData = new PortalCommerceApiQuotes.QuoteInfo();
        quoteData.quoteNumber = '123';
        quoteData.upcomingBills = new PortalCommerceApiQuotes.BillItem();
        quoteData.upcomingBills.subTotal = 12345;
        quoteData.upcomingBills.lines = new List<PortalCommerceApiQuotes.BillLineItem>();
        quoteData.expiresAt = Datetime.now().addYears(1).getTime();
        PortalCommerceApiQuotes.BillLineItem item = new PortalCommerceApiQuotes.BillLineItem();
        item.total = 12345;
        item.subTotal = 12345;
        item.quantity = 1;
        quoteData.upcomingBills.lines.add(item);

        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        log.productLog = new List<String>{'Test1'};
        log.pbeLog = new List<String>{'Test2'};

        List<OpportunityLineItem> oppProductsResponse = new List<OpportunityLineItem>();
        OpportunityLineItem oli = new OpportunityLineItem();
        oli.OpportunityId = opp.Id;
        oppProductsResponse.add(oli);

        mockService
            .when('mapProducts')
            .thenReturn(oppProductsResponse);

        Test.startTest();
        Double conversionFactor = 1.0;
        List<OpportunityLineItem> oppProducts = PpcQuoteConverter.mapProducts(quoteData, opp, conversionFactor, log, true);
        Test.stopTest();

        System.assertNotEquals(null, oppProducts, 'OppProducts should not be null');
        System.assertEquals(1, oppProducts.size(), 'Should have one product');
        System.debug(oppProducts);
    }

    @IsTest
    static void testConvertInvoiceSuccessful() {
        testSetup();

        Account acc = TestDataFactory.getAccount('FI', 'EUR');
        acc.CV_Subsidiary__c = 'FI';
        acc.BillingCountry = 'Finland';
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.Pricebook2Id = Test.getStandardPricebookId();
        insert opp;

        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        log.productLog = new List<String>{'Test1'};
        log.pbeLog = new List<String>{'Test2'};

        Product2 prod = TestDataFactory.getProduct();
        insert prod;

        PricebookEntry pbe = TestDataFactory.getPbEntry(Test.getStandardPricebookId(), prod.Id, 'EUR');
        insert pbe;

        List<OpportunityLineItem> oppProductsResponse = new List<OpportunityLineItem>();
        OpportunityLineItem oli = new OpportunityLineItem();
        oli.OpportunityId = opp.Id;
        oli.User_Count__c = 1;
        oli.Renewal__c = 'Renewal (CV Owned)';
        oli.PricebookEntryId = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :opp.Pricebook2Id LIMIT 1].Id;
        oppProductsResponse.add(oli);

        mockService
            .when('mapProducts')
            .thenReturn(oppProductsResponse);

        Double conversionFactor = 1.0;
        PortalCommerceApiQuotes.QuoteInfo quoteDataResponse = new PortalCommerceApiQuotes.QuoteInfo();
        quoteDataResponse.quoteNumber = '123';
        quoteDataResponse.upcomingBills = new PortalCommerceApiQuotes.BillItem();
        quoteDataResponse.upcomingBills.subTotal = 12345;
        quoteDataResponse.upcomingBills.lines = new List<PortalCommerceApiQuotes.BillLineItem>();
        quoteDataResponse.expiresAt = Datetime.now().addYears(1).getTime();
        PortalCommerceApiQuotes.BillLineItem item = new PortalCommerceApiQuotes.BillLineItem();
        item.total = 12345;
        item.subTotal = 12345;
        item.quantity = 1;
        quoteDataResponse.upcomingBills.lines.add(item);
        String jsonText = JSON.serialize(quoteDataResponse);

        Test.startTest();
        OpportunityProductMapper.LogData logData = PpcQuoteConverter.convertQuote(jsonText, opp.Id, true, true);
        Test.stopTest();

        System.assertNotEquals(null, logData, 'LogData should not be null');
        System.assertEquals(2, logData.successLog.size(), 'Should have two success log');
        System.assert(logData.successLog[0].containsIgnoreCase('Opportunity Products added successfully'), 'Should have success log for adding opportunity products');
        System.assert(logData.successLog[1].containsIgnoreCase('Opportunity updated successfully'), 'Should have success log for updating opportunity');
        System.debug(logData);
    }
}