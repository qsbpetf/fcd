trigger OpportunityReadiness on Opportunity (after update) {
    OpportunityReadinessTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
}