trigger MakeWebhookOpportunityLineItemTrigger on OpportunityLineItem (after delete) {
    if (Trigger.isAfter && Trigger.isDelete) {
        MakeWebhookOpportunityHandler.handleOLIAfterDelete(Trigger.old);
    }
}