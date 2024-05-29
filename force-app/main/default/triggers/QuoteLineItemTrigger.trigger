trigger QuoteLineItemTrigger on QuoteLineItem (before insert)
{
    if(Trigger.isBefore)
    {
        if(Trigger.isInsert)
        {
            OpportunityQuoteSynchronizer.newQuoteLineItems(Trigger.new);
        }
    }
}