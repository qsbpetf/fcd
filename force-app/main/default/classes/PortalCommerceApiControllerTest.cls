/**
 * Created by peterfriberg on 2024-09-24.
 */

@IsTest
private class PortalCommerceApiControllerTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiQuotes mockServiceStub;

    private static final UniversalMocker mockServiceEnt;
    private static final PortalCommerceApiEntitlements mockServiceEntStub;

    private static final UniversalMocker mockServiceInv;
    private static final PortalCommerceApiInvoices mockServiceInvStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiQuotes.class);
        mockServiceStub = (PortalCommerceApiQuotes) mockService.createStub();
        PortalCommerceApiQuotes.instance = new PortalCommerceApiQuotes();
        PortalCommerceApiController.setApiQuotes(mockServiceStub);

        mockServiceEnt = UniversalMocker.mock(PortalCommerceApiEntitlements.class);
        mockServiceEntStub = (PortalCommerceApiEntitlements) mockServiceEnt.createStub();
        PortalCommerceApiEntitlements.instance = new PortalCommerceApiEntitlements();
        PortalCommerceApiController.setApiEntitlements(mockServiceEntStub);

        mockServiceInv = UniversalMocker.mock(PortalCommerceApiInvoices.class);
        mockServiceInvStub = (PortalCommerceApiInvoices) mockServiceInv.createStub();
        PortalCommerceApiInvoices.instance = new PortalCommerceApiInvoices();
        PortalCommerceApiController.setApiInvoices(mockServiceInvStub);
    }

    @IsTest
    static void testGetQuotesSuccessful() {
        PortalCommerceApiQuotes.QuoteList quotesToReturn = new PortalCommerceApiQuotes.QuoteList();
        PortalCommerceApiQuotes.QuoteInfo aQuote = new PortalCommerceApiQuotes.QuoteInfo();
        aQuote.quoteNumber = '123';
        aQuote.id = '123456';
        aQuote.lineItems = new List<PortalCommerceApiQuotes.QuoteItem>();
        quotesToReturn.data.add(aQuote);

        mockService
            .when('getQuotes')
            .thenReturn(quotesToReturn);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        System.debug('AIP QUOTES =' + PortalCommerceApiController.apiQuotes);

        Test.startTest();
        PortalCommerceApiQuotes.QuoteList quotes = PortalCommerceApiController.getQuotes(opp.Id);
        Test.stopTest();

        System.debug('QUOTES = ' + quotes);

        System.assertEquals(1, quotes.data.size(), 'Should have one quote');
        System.assertEquals('123', quotes.data[0].quoteNumber, 'Wrong quote number');
        System.assertEquals('123456', quotes.data[0].id, 'Wrong quote number');
    }

    @IsTest
    static void testGetQuoteSuccessful() {
        PortalCommerceApiQuotes.QuoteInfo quoteToReturn = new PortalCommerceApiQuotes.QuoteInfo();
        quoteToReturn.quoteNumber = '123';
        quoteToReturn.id = '123456';
        quoteToReturn.lineItems = new List<PortalCommerceApiQuotes.QuoteItem>();

        mockService
            .when('getQuote')
            .thenReturn(quoteToReturn);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        Test.startTest();
        PortalCommerceApiQuotes.QuoteInfo quote = PortalCommerceApiController.getQuote(opp.Id, '123456');
        Test.stopTest();

        System.debug('QUOTE = ' + quote);

        System.assertEquals('123', quote.quoteNumber, 'Wrong quote number');
        System.assertEquals('123456', quote.id, 'Wrong quote number');
    }

    @IsTest
    static void GetEntitlementDisplayInfoSuccessful() {
        PortalCommerceApiEntitlements.EntitlementDisplayInfo entitlementDisplayInfoToReturn = new PortalCommerceApiEntitlements.EntitlementDisplayInfo();
        entitlementDisplayInfoToReturn.entitlementId = '123456';
        entitlementDisplayInfoToReturn.provisionedResource = new PortalCommerceApiEntitlements.provisionedResourceInfo();
        entitlementDisplayInfoToReturn.provisionedResource.name = 'test_name';
        entitlementDisplayInfoToReturn.provisionedResource.ari = 'test_ari';

        mockServiceEnt
            .when('getEntitlementDisplayInfo')
            .thenReturn(entitlementDisplayInfoToReturn);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        Test.startTest();
        PortalCommerceApiEntitlements.EntitlementDisplayInfo entInfo = PortalCommerceApiController.getEntitlementDisplayInfo(opp.Id, '123456');
        Test.stopTest();

        System.debug('ENTITLEMENT = ' + entInfo);

        System.assertEquals('123456', entInfo.entitlementId, 'Wrong entitlementId');
        System.assertEquals('test_name', entInfo.provisionedResource.name, 'Wrong name');
        System.assertEquals('test_ari', entInfo.provisionedResource.ari, 'Wrong ari');
    }

    @IsTest
    static void GetEntitlementDetailsSuccessful() {
        PortalCommerceApiEntitlements.EntitlementDetails entitlementDetailsToReturn = new PortalCommerceApiEntitlements.EntitlementDetails();
        entitlementDetailsToReturn.entitlementId = '123456';
        entitlementDetailsToReturn.status = 'OK';
        entitlementDetailsToReturn.slug = 'SLUG';

        mockServiceEnt
            .when('getEntitlementDetails')
            .thenReturn(entitlementDetailsToReturn);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        Test.startTest();
        PortalCommerceApiEntitlements.EntitlementDetails details = PortalCommerceApiController.getEntitlementDetails(opp.Id, '123456');
        Test.stopTest();

        System.debug('ENTITLEMENT = ' + details);

        System.assertEquals('123456', details.entitlementId, 'Wrong entitlementId');
        System.assertEquals('OK', details.status, 'Wrong status');
        System.assertEquals('SLUG', details.slug, 'Wrong slug');
    }

    @IsTest
    private static void testGetInvoicesSuccessful() {
        PortalCommerceApiInvoices.InvoiceList invoicesToReturn = new PortalCommerceApiInvoices.InvoiceList();
        PortalCommerceApiInvoices.InvoiceInfo invoice = new PortalCommerceApiInvoices.InvoiceInfo();
        invoice.invoiceNumber = '123';
        invoice.id = '123456';
        invoicesToReturn.data.add(invoice);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        acc.CV_Subsidiary__c = 'FI';
        insert acc;
        InvoiceGroup__c invoiceGroup = TestDataFactory.getInvoiceGroup(acc.Id);
        insert invoiceGroup;

        mockServiceInv
            .when('getInvoices')
            .thenReturn(invoicesToReturn);

        Test.startTest();
        List<PortalCommerceApiInvoices.InvoiceList> invoices = PortalCommerceApiController.getInvoices(acc.Id);
        Test.stopTest();

        System.assertEquals(1, invoices.size(), 'Should have one invoice');
        System.assertEquals(1, invoices[0].data.size(), 'Should have one invoice');
    }
}