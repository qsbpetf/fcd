/**
 * Keeps Quote.Offer_Introduction__c and Quote.Terms_And_Conditions__c in sync with the quote's products.
 *
 * Runs when:  a quote line is added or removed  |  a quote is created  |
 *             variant, offer type, language, governing agreement, bespoke terms or the lock changes.
 * Skipped when:  Quote.Terms_Locked__c = true (manual legal edits)  |  Quote_Terms_Settings__c.Disable_Auto_Terms__c = true.
 */
public with sharing class QuoteTermsService {

    private static Boolean running = false;

    private static final List<Schema.SObjectField> WATCHED_QUOTE_FIELDS = new List<Schema.SObjectField>{
        Quote.Template_Variant__c, Quote.Offer_Type__c, Quote.Quote_Language__c,
        Quote.Governing_Agreement__c, Quote.Governing_Agreement_Date__c, Quote.Bespoke_Terms__c, Quote.Terms_Locked__c
    };

    // --------------------------------------------------------------------------- trigger entries
    public static void onLineItemsChanged(List<QuoteLineItem> rows) {
        if (isDisabled()) return;
        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem r : rows) if (r.QuoteId != null) quoteIds.add(r.QuoteId);
        refresh(quoteIds, false);
    }

    public static void onQuotesInserted(List<Quote> rows) {
        if (isDisabled()) return;
        refresh(new Map<Id, Quote>(rows).keySet(), false);
    }

    public static void onQuotesUpdated(List<Quote> rows, Map<Id, Quote> oldMap) {
        if (isDisabled()) return;
        Set<Id> changed = new Set<Id>();
        for (Quote q : rows) {
            Quote old = oldMap.get(q.Id);
            for (Schema.SObjectField f : WATCHED_QUOTE_FIELDS) {
                if (q.get(f) != old.get(f)) { changed.add(q.Id); break; }
            }
        }
        refresh(changed, false);
    }

    /** Flow / Process entry point: "Refresh Quote Terms & Conditions" (ignores the lock). */
    @InvocableMethod(label='Refresh Quote Terms & Conditions'
                     description='Regenerates the offer introduction and Terms & Conditions from the quote products.')
    public static void refreshFromFlow(List<Id> quoteIds) {
        refresh(new Set<Id>(quoteIds), true);
    }

    // ----------------------------------------------------------------------------------- core
    /**
     * @param force true = regenerate even if Terms_Locked__c is set (explicit user action).
     * @return number of quotes updated
     */
    public static Integer refresh(Set<Id> quoteIds, Boolean force) {
        if (running || quoteIds == null || quoteIds.isEmpty()) return 0;

        Map<Id, Quote> quotes = new Map<Id, Quote>([
            SELECT Id, Terms_Locked__c, Governing_Agreement__c, Governing_Agreement_Date__c, Bespoke_Terms__c
            FROM Quote WHERE Id IN :quoteIds
        ]);
        Set<Id> toBuild = new Set<Id>();
        for (Quote q : quotes.values()) if (force || !q.Terms_Locked__c) toBuild.add(q.Id);
        if (toBuild.isEmpty()) return 0;

        Map<Id, QuoteTermsResolver.Resolution> resolutions = QuoteTermsResolver.resolveAll(toBuild, null);
        List<Quote> updates = new List<Quote>();
        for (Id quoteId : toBuild) {
            QuoteTermsResolver.Resolution r = resolutions.get(quoteId);
            if (r == null) continue;
            Quote q = quotes.get(quoteId);
            updates.add(new Quote(
                Id = quoteId,
                Offer_Introduction__c = QuoteTermsBuilder.introHtml(r),
                Terms_And_Conditions__c = QuoteTermsBuilder.termsHtml(r, q.Governing_Agreement__c,
                    q.Governing_Agreement_Date__c, q.Bespoke_Terms__c)
            ));
        }
        running = true;
        try {
            update updates;
        } finally {
            running = false;
        }
        return updates.size();
    }

    public static Boolean isDisabled() {
        Quote_Terms_Settings__c s = Quote_Terms_Settings__c.getInstance();
        return s != null && s.Disable_Auto_Terms__c == true;
    }
}