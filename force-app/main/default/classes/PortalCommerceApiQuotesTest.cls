/**
 * Created by peterfriberg on 2024-09-24.
 */

@IsTest
private class PortalCommerceApiQuotesTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        // PortalCommerceApiQuotes.client = mockServiceStub;
        PortalCommerceApiQuotes.instance = new PortalCommerceApiQuotes();
        PortalCommerceApiQuotes.setApiClient(mockServiceStub);
    }

    @IsTest
    static void testGetInstance() {
        PortalCommerceApiQuotes.instance = null;
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        System.assertNotEquals(null, instance, 'Instance should not be null');
        System.assertNotEquals(null, PortalCommerceApiQuotes.client, 'Client should not be null');
    }

    @IsTest
    static void testGetQuotesSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","number":"123","lineItems":[]}]}');

        mockService
            .when('getQuotes')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        PortalCommerceApiQuotes.QuoteList quotes = instance.getQuotes('FI', 10, null);
        Test.stopTest();

        System.debug('QUOTES = ' + quotes);
        System.assertNotEquals(null, quotes, 'Quotes should not be null');
        System.assertEquals(1, quotes.data.size(), 'Should have one quote');
        System.assertEquals('123', quotes.data[0].quoteNumber, 'Wrong quote number');
        System.assertEquals('123456', quotes.data[0].id, 'Wrong quote number');
    }

    @IsTest
    static void testGetQuotesNot200Ok() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setStatus('Internal Server Error');
        response.setBody('{"error":"Internal Server Error"}');

        mockService
            .when('getQuotes')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        PortalCommerceApiQuotes.QuoteList quotes = instance.getQuotes('FI', 10, null);
        Test.stopTest();

        System.debug('QUOTES = ' + quotes);
        System.assertNotEquals(null, quotes, 'Quotes should not be null');
        System.assertEquals('{"error":"Internal Server Error"}', quotes.error, 'Wrong error message');
        System.assertEquals(true, quotes.missingAccountId, 'Should be missing account id');
    }

    @IsTest
    static void testGetQuotesStaticSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","number":"123","lineItems":[]}]}');

        mockService
            .when('getQuotes')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiQuotes.QuoteList quotes = PortalCommerceApiQuotes.getQuotesStatic('FI', 10, null);
        Test.stopTest();

        System.debug('QUOTES = ' + quotes);
        System.assertNotEquals(null, quotes, 'Quotes should not be null');
        System.assertEquals(1, quotes.data.size(), 'Should have one quote');
        System.assertEquals('123', quotes.data[0].quoteNumber, 'Wrong quote number');
        System.assertEquals('123456', quotes.data[0].id, 'Wrong quote number');
    }

    @IsTest
    static void testGetQuoteSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"id":"123456","number":"123","lineItems":[]}');

        mockService
            .when('getQuote')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        PortalCommerceApiQuotes.QuoteInfo quote = instance.getQuote('FI', '123456');
        Test.stopTest();

        System.debug('QUOTE = ' + quote);
        System.assertNotEquals(null, quote, 'Quote should not be null');
        System.assertEquals('123456', quote.id, 'Wrong quote number');
        System.assertEquals('123', quote.quoteNumber, 'Wrong quote number');
    }

    @IsTest
    static void testGetQuoteStaticSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"id":"123456","number":"123","lineItems":[]}');

        mockService
            .when('getQuote')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiQuotes.QuoteInfo quote = PortalCommerceApiQuotes.getQuoteStatic('FI', '123456');
        Test.stopTest();

        System.debug('QUOTE = ' + quote);
        System.assertNotEquals(null, quote, 'Quote should not be null');
        System.assertEquals('123456', quote.id, 'Wrong quote number');
        System.assertEquals('123', quote.quoteNumber, 'Wrong quote number');
    }

    @IsTest
    static void testGetQuoteNot200Ok() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setStatus('Internal Server Error');
        response.setBody('{"error":"Internal Server Error"}');

        mockService
            .when('getQuote')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        PortalCommerceApiQuotes.QuoteInfo quote = instance.getQuote('FI', '123456');
        Test.stopTest();

        System.debug('QUOTE = ' + quote);
        System.assertNotEquals(null, quote, 'Quote should not be null');
        System.assertEquals('{"error":"Internal Server Error"}', quote.error, 'Wrong error message');
        System.assertEquals(true, quote.missingAccountId, 'Should be missing account id');
    }

    @IsTest
    static void testGetQuotePdfSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('PDF');

        mockService
            .when('getQuotePdf')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        String pdf = instance.getQuotePdf('FI', '123456');
        Test.stopTest();

        System.debug('PDF = ' + pdf);
        System.assertNotEquals(null, pdf, 'PDF should not be null');
        System.assertEquals('PDF', EncodingUtil.base64Decode(pdf).toString(), 'Wrong PDF');
    }

    @IsTest
    static void testGetQuotePdfStaticSuccessful() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('PDF');

        mockService
            .when('getQuotePdf')
            .thenReturn(response);

        Test.startTest();
        String pdf = PortalCommerceApiQuotes.getQuotePdfStatic('FI', '123456');
        Test.stopTest();

        System.debug('PDF = ' + pdf);
        System.assertNotEquals(null, pdf, 'PDF should not be null');
        System.assertEquals('PDF', EncodingUtil.base64Decode(pdf).toString(), 'Wrong PDF');
    }

    @IsTest
    static void testGetQuotePdfNot200Ok() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setStatus('Internal Server Error');
        response.setBody('{"error":"Internal Server Error"}');

        mockService
            .when('getQuotePdf')
            .thenReturn(response);

        Test.startTest();
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        String pdf = instance.getQuotePdf('FI', '123456');
        Test.stopTest();

        System.debug('PDF = ' + pdf);
        System.assertNotEquals(null, pdf, 'PDF should not be null');
        System.assertEquals('{"error":"Internal Server Error"}', pdf, 'Wrong error message');
    }
}