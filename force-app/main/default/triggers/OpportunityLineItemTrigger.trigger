trigger OpportunityLineItemTrigger on OpportunityLineItem (after insert)
{
    if(Trigger.isAfter)
    {
        if(Trigger.isInsert)
        {
            OpportunityQuoteSynchronizer.newOpportunityLineItems(Trigger.new);
        }
    }
}