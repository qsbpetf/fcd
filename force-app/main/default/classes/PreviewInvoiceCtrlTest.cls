/**
 * Created by peterfriberg on 2025-03-13.
 */

@IsTest
private class PreviewInvoiceCtrlTest {
    private static final UniversalMocker mockService;
    private static final PortalCommerceApiInvoices mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiInvoices.class);
        mockServiceStub = (PortalCommerceApiInvoices) mockService.createStub();
        PortalCommerceApiInvoices.instance = new PortalCommerceApiInvoices();
        PortalCommerceApiController.setApiInvoices(mockServiceStub);
    }

    @IsTest
    static void returnsErrorForNullParamaters() {
        PreviewInvoiceCtrl controller = new PreviewInvoiceCtrl();
        System.assertEquals('application/pdf', controller.contenttype);
        System.assertEquals('Sorry for the inconvenience! Required parameters are missing.', controller.errorMessage);
        System.assertEquals('OFFICE and INVOICE_ID are required parameters.', controller.errorDetails);
    }

    @IsTest
    static void returnPdfSuccessfully() {
        mockService
            .when('getInvoicePdf')
            .thenReturn('pdf');

        PageReference pageRef = Page.PreviewInvoice; // Replace with actual page reference
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('OFFICE', 'FI');
        ApexPages.currentPage().getParameters().put('INVOICE_ID', 'Q_ID');

        Test.startTest();
        PreviewInvoiceCtrl controller = new PreviewInvoiceCtrl();
        Test.stopTest();

        System.assertEquals('application/pdf', controller.contenttype);
        System.assertEquals('pdf', controller.pdf);
        System.assertEquals(null, controller.errorMessage);
        System.assertEquals(null, controller.errorDetails);
    }
    @IsTest
    static void returnErrorOnException() {
        mockService
            .when('getInvoicePdf')
            .thenThrow(new NullPointerException());

        PageReference pageRef = Page.PreviewInvoice; // Replace with actual page reference
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('OFFICE', 'FI');
        ApexPages.currentPage().getParameters().put('INVOICE_ID', 'Q_ID');

        Test.startTest();
        PreviewInvoiceCtrl controller = new PreviewInvoiceCtrl();
        Test.stopTest();

        System.assertEquals('application/pdf', controller.contenttype);
        System.assertEquals(null, controller.pdf);
        System.assertEquals('Sorry for the inconvenience! Error when generating PDF from Atlassian PPC .', controller.errorMessage);
        System.assertNotEquals(null, controller.errorDetails);
    }
}