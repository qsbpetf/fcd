/** Regenerates the quote's Terms & Conditions whenever products are added to or removed from it. */
trigger QuoteLineItemTermsTrigger on QuoteLineItem (after insert, after delete, after undelete) {
    QuoteTermsService.onLineItemsChanged(Trigger.isDelete ? Trigger.old : Trigger.new);
}