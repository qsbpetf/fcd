/**
 * Created by peterfriberg on 2025-02-25.
 */

public with sharing class PreviewInvoiceCtrl {
    public String contenttype {
        get {
            return 'application/pdf';
        }
        private set;
    }

    public String pdf { get; private set; }
    public String errorMessage { get; private set; }
    public String errorDetails { get; private set; }

    /**
     * Constructor that sets the pdf Base64 encoded data.
     */
    public PreviewInvoiceCtrl() {
        Map<String, String> parameters = ApexPages.currentPage().getParameters();
        String office = parameters.get('OFFICE');
        String invoiceId = parameters.get('INVOICE_ID');

        if (office == null || invoiceId == null) {
            errorMessage = 'Sorry for the inconvenience! Required parameters are missing.';
            errorDetails = 'OFFICE and INVOICE_ID are required parameters.';
            return;
        }

        try {
            pdf = PortalCommerceApiController.getInvoicePdfStatic(office, invoiceId);
        }
        catch (Exception ex) {
            String error = ex.getMessage();
            errorMessage = 'Sorry for the inconvenience! Error when generating PDF from Atlassian PPC .';
            errorDetails = error;
        }
    }
}