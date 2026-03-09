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

    private static final UniversalMocker mockServiceOrd;
    private static final PortalCommerceApiOrders mockServiceOrdStub;

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

        mockServiceOrd = UniversalMocker.mock(PortalCommerceApiOrders.class);
        mockServiceOrdStub = (PortalCommerceApiOrders) mockServiceOrd.createStub();
        PortalCommerceApiOrders.instance = new PortalCommerceApiOrders();
        PortalCommerceApiController.setApiOrders(mockServiceOrdStub);
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
        quoteToReturn.upcomingBills = new PortalCommerceApiQuotes.BillItem();
        quoteToReturn.upcomingBills.lines = new List<PortalCommerceApiQuotes.BillLineItem>();

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
        invoice.items = new List<PortalCommerceApiInvoices.InvoiceItem>();
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

    @IsTest
    static void testGetPaidInvoicesSuccessful() {
        PortalCommerceApiInvoices.InvoiceList invoicesToReturn = new PortalCommerceApiInvoices.InvoiceList();
        PortalCommerceApiInvoices.InvoiceInfo invoice = new PortalCommerceApiInvoices.InvoiceInfo();
        invoice.invoiceNumber = '123';
        invoice.id = '123456';
        invoice.paidAt = Datetime.now().getTime();
        invoice.items = new List<PortalCommerceApiInvoices.InvoiceItem>();
        invoicesToReturn.data.add(invoice);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        acc.CV_Subsidiary__c = 'FI';
        insert acc;
        InvoiceGroup__c invoiceGroup = TestDataFactory.getInvoiceGroup(acc.Id);
        insert invoiceGroup;

        mockServiceInv
            .when('getPaidInvoices')
            .thenReturn(invoicesToReturn);

        Test.startTest();
        List<PortalCommerceApiInvoices.InvoiceList> invoices = PortalCommerceApiController.getPaidInvoices(acc.Id, 100);
        Test.stopTest();

        System.assertEquals(1, invoices.size(), 'Should have one invoice batch');
        System.assertEquals(1, invoices[0].data.size(), 'Should have one paid invoice');
        System.assertEquals('FI', invoices[0].data[0].office, 'Office should be set for display');
    }

    @IsTest
    static void testGetQuoteReturnsNull() {
        mockService
            .when('getQuote')
            .thenReturn(null);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        Test.startTest();
        PortalCommerceApiQuotes.QuoteInfo quote = PortalCommerceApiController.getQuote(opp.Id, '123456');
        Test.stopTest();

        System.assertEquals(null, quote, 'Should return null when API returns null');
    }

    @IsTest
    static void testGetInvoiceSuccessful() {
        PortalCommerceApiInvoices.InvoiceInfo invoiceToReturn = new PortalCommerceApiInvoices.InvoiceInfo();
        invoiceToReturn.invoiceNumber = '123';
        invoiceToReturn.id = '123456';
        invoiceToReturn.status = 'PAID';
        invoiceToReturn.items = new List<PortalCommerceApiInvoices.InvoiceItem>();

        mockServiceInv
            .when('getInvoice')
            .thenReturn(invoiceToReturn);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        acc.CV_Subsidiary__c = 'FI';
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        opp.AccountId = acc.Id;
        insert opp;

        Test.startTest();
        PortalCommerceApiInvoices.InvoiceInfo invoice = PortalCommerceApiController.getInvoice(opp.Id, '123456');
        Test.stopTest();

        System.assertNotEquals(null, invoice, 'Invoice should not be null');
        System.assertEquals('123456', invoice.id, 'Wrong invoice id');
        System.assertEquals('FI', invoice.office, 'Office should be set');
    }

    @IsTest
    static void testGetInvoiceReturnsNull() {
        mockServiceInv
            .when('getInvoice')
            .thenReturn(null);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        acc.CV_Subsidiary__c = 'FI';
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        opp.AccountId = acc.Id;
        insert opp;

        Test.startTest();
        PortalCommerceApiInvoices.InvoiceInfo invoice = PortalCommerceApiController.getInvoice(opp.Id, '123456');
        Test.stopTest();

        System.assertEquals(null, invoice, 'Should return null when API returns null');
    }

    @IsTest
    static void testGetOrderSuccessful() {
        PortalCommerceApiOrders.OrderInfo orderToReturn = new PortalCommerceApiOrders.OrderInfo();
        orderToReturn.orderId = 'ord-123';
        orderToReturn.slug = 'test-slug';
        orderToReturn.items = new List<PortalCommerceApiOrders.OrderItem>();

        mockServiceOrd
            .when('getOrder')
            .thenReturn(orderToReturn);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        acc.CV_Subsidiary__c = 'FI';
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        opp.AccountId = acc.Id;
        insert opp;

        Test.startTest();
        PortalCommerceApiOrders.OrderInfo order = PortalCommerceApiController.getOrder(opp.Id, 'ord-123');
        Test.stopTest();

        System.assertNotEquals(null, order, 'Order should not be null');
        System.assertEquals('ord-123', order.orderId, 'Wrong order id');
        System.assertEquals('FI', order.office, 'Office should be set');
    }

    @IsTest
    static void testGetOrderReturnsNull() {
        mockServiceOrd
            .when('getOrder')
            .thenReturn(null);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        acc.CV_Subsidiary__c = 'FI';
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        opp.AccountId = acc.Id;
        insert opp;

        Test.startTest();
        PortalCommerceApiOrders.OrderInfo order = PortalCommerceApiController.getOrder(opp.Id, 'ord-123');
        Test.stopTest();

        System.assertEquals(null, order, 'Should return null when API returns null');
    }

    @IsTest
    static void testGetOrderPreviewSuccessful() {
        PortalCommerceApiOrders.OrderInfo orderToReturn = new PortalCommerceApiOrders.OrderInfo();
        orderToReturn.orderId = 'ord-preview-456';
        orderToReturn.items = new List<PortalCommerceApiOrders.OrderItem>();

        mockServiceOrd
            .when('getOrderPreview')
            .thenReturn(orderToReturn);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        acc.CV_Subsidiary__c = 'FI';
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        opp.AccountId = acc.Id;
        insert opp;

        Test.startTest();
        PortalCommerceApiOrders.OrderInfo order = PortalCommerceApiController.getOrderPreview(opp.Id, 'quote-789', 5);
        Test.stopTest();

        System.assertNotEquals(null, order, 'Order preview should not be null');
        System.assertEquals('ord-preview-456', order.orderId, 'Wrong order id');
        System.assertEquals('FI', order.office, 'Office should be set');
    }

    @IsTest
    static void testGetOrderPreviewReturnsNull() {
        mockServiceOrd
            .when('getOrderPreview')
            .thenReturn(null);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        acc.CV_Subsidiary__c = 'FI';
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        opp.AccountId = acc.Id;
        insert opp;

        Test.startTest();
        PortalCommerceApiOrders.OrderInfo order = PortalCommerceApiController.getOrderPreview(opp.Id, 'quote-789', 5);
        Test.stopTest();

        System.assertEquals(null, order, 'Should return null when API returns null');
    }

    @IsTest
    static void testGetEntitlementPartnerInfoSuccessful() {
        PortalCommerceApiEntitlements.EntitlementPartnerInfo partnerInfoToReturn = new PortalCommerceApiEntitlements.EntitlementPartnerInfo();
        partnerInfoToReturn.entitlementId = 'ent-123';
        partnerInfoToReturn.status = 'ACTIVE';
        partnerInfoToReturn.slug = 'partner-slug';

        mockServiceEnt
            .when('getEntitlementPartnerInfo')
            .thenReturn(partnerInfoToReturn);

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        Test.startTest();
        PortalCommerceApiEntitlements.EntitlementPartnerInfo partnerInfo = PortalCommerceApiController.getEntitlementPartnerInfo(opp.Id, 'ent-123');
        Test.stopTest();

        System.assertNotEquals(null, partnerInfo, 'Partner info should not be null');
        System.assertEquals('ent-123', partnerInfo.entitlementId, 'Wrong entitlement id');
        System.assertEquals('ACTIVE', partnerInfo.status, 'Wrong status');
    }

    @IsTest
    static void testGetQuotePdfStatic() {
        mockService
            .when('getQuotePdf')
            .thenReturn('base64EncodedPdfContent');

        Test.startTest();
        String pdfResult = PortalCommerceApiController.getQuotePdfStatic('FI', 'quote-123');
        Test.stopTest();

        System.assertEquals('base64EncodedPdfContent', pdfResult, 'Should return PDF content');
    }

    @IsTest
    static void testGetInvoicePdfStatic() {
        mockServiceInv
            .when('getInvoicePdf')
            .thenReturn('base64EncodedInvoicePdf');

        Test.startTest();
        String pdfResult = PortalCommerceApiController.getInvoicePdfStatic('FI', 'inv-456');
        Test.stopTest();

        System.assertEquals('base64EncodedInvoicePdf', pdfResult, 'Should return invoice PDF content');
    }
}