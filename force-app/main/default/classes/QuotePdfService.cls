/**
 * Entry points for the "Offer PDF & Terms" quick action (LWC quotePdfAction).
 */
public with sharing class QuotePdfService {

    /** Shows which products bring which terms, plus variant / language / offer type – without saving. */
    @AuraEnabled(cacheable=true)
    public static QuoteTermsResolver.Resolution getResolution(Id quoteId, String languageOverride) {
        try {
            QuoteTermsResolver.Resolution r = QuoteTermsResolver.resolve(quoteId, languageOverride);
            for (QuoteTermsResolver.ModuleView m : r.modules) m.body = null; // not needed in the UI
            return r;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    /** Rewrites Offer_Introduction__c and Terms_And_Conditions__c on the Quote now (also when locked). */
    @AuraEnabled
    public static void regenerateTerms(Id quoteId) {
        try {
            if (quoteId == null) throw new IllegalArgumentException('Quote Id is required.');
            QuoteTermsService.refresh(new Set<Id>{ quoteId }, true);
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    /** Renders the Visualforce page as PDF and stores it on the Quote (Quote > PDFs related list). */
    @AuraEnabled
    public static Id savePdf(Id quoteId, String languageOverride) {
        try {
            PageReference page = Page.QuoteModularPdf;
            page.getParameters().put('id', quoteId);
            if (String.isNotBlank(languageOverride)) page.getParameters().put('lang', languageOverride);
            Blob pdf = Test.isRunningTest() ? Blob.valueOf('test pdf') : page.getContentAsPDF();

            QuoteDocument doc = new QuoteDocument(QuoteId = quoteId, Document = pdf);
            insert doc;
            return doc.Id;
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    private static AuraHandledException auraError(Exception e) {
        AuraHandledException ae = new AuraHandledException(e.getMessage());
        ae.setMessage(e.getMessage());
        return ae;
    }
}