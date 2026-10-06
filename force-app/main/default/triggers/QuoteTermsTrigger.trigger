/** Regenerates Terms & Conditions when a quote is created or a T&C-relevant field changes. */
trigger QuoteTermsTrigger on Quote (after insert, after update) {
    if (Trigger.isInsert) {
        QuoteTermsService.onQuotesInserted(Trigger.new);
    } else {
        QuoteTermsService.onQuotesUpdated(Trigger.new, Trigger.oldMap);
    }
}