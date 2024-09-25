/**
 * Created by peterfriberg on 2024-09-25.
 */

@IsTest
private class PreviewQuoteCtrlTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiQuotes mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiQuotes.class);
        mockServiceStub = (PortalCommerceApiQuotes) mockService.createStub();
        PortalCommerceApiQuotes.instance = new PortalCommerceApiQuotes();
        PortalCommerceApiController.setApiQuotes(mockServiceStub);
    }

    @IsTest
    static void returnsErrorForNullParamaters() {
        PreviewQuoteCtrl controller = new PreviewQuoteCtrl();
        System.assertEquals('application/pdf', controller.contenttype);
        System.assertEquals('Sorry for the inconvenience! Required parameters are missing.', controller.errorMessage);
        System.assertEquals('OFFICE and QUOTE_ID are required parameters.', controller.errorDetails);
    }

    @IsTest
    static void returnPdfSuccessfully() {
        mockService
            .when('getQuotePdf')
            .thenReturn('pdf');

        PageReference pageRef = Page.PreviewQuote; // Replace with actual page reference
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('OFFICE', 'FI');
        ApexPages.currentPage().getParameters().put('QUOTE_ID', 'Q_ID');

        Test.startTest();
        PreviewQuoteCtrl controller = new PreviewQuoteCtrl();
        Test.stopTest();

        System.assertEquals('application/pdf', controller.contenttype);
        System.assertEquals('pdf', controller.pdf);
        System.assertEquals(null, controller.errorMessage);
        System.assertEquals(null, controller.errorDetails);
    }
    @IsTest
    static void returnErrorOnException() {
        mockService
            .when('getQuotePdf')
            .thenThrow(new NullPointerException());

        PageReference pageRef = Page.PreviewQuote; // Replace with actual page reference
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('OFFICE', 'FI');
        ApexPages.currentPage().getParameters().put('QUOTE_ID', 'Q_ID');

        Test.startTest();
        PreviewQuoteCtrl controller = new PreviewQuoteCtrl();
        Test.stopTest();

        System.assertEquals('application/pdf', controller.contenttype);
        System.assertEquals(null, controller.pdf);
        System.assertEquals('Sorry for the inconvenience! Error when generating PDF from Atlassian PPC .', controller.errorMessage);
        System.assertNotEquals(null, controller.errorDetails);
    }
}