trigger QuoteTrigger on Quote (before insert, after update)
{
    if(Trigger.isBefore)
    {
        if(Trigger.isInsert)
        {
            OpportunityQuoteSynchronizer.newQuotes(Trigger.new);
        }
    }
    else if(Trigger.isAfter)
    {
        if(Trigger.isUpdate)
        {
            OpportunityQuoteSynchronizer.quotesUpdated(Trigger.new, Trigger.oldMap);
        }
    }
}