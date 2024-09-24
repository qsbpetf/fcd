/**
 * Created by peterfriberg on 2024-09-18.
 */

public with sharing class PreviewQuoteCtrl {
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
    public PreviewQuoteCtrl() {
        Map<String, String> parameters = ApexPages.currentPage().getParameters();
        String office = parameters.get('OFFICE');
        String quoteId = parameters.get('QUOTE_ID');

        try {
            pdf = PortalCommerceApiQuotes.getQuotePdfStatic(office, quoteId);
        }
        catch (Exception ex) {
            String error = ex.getMessage();
            errorMessage = 'Sorry for the inconvenience! Error from Metaforce when generating PDF. Please look in Apex Log to find error.';
            errorDetails = error;
        }
    }
}