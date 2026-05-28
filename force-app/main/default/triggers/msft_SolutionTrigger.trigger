trigger msft_SolutionTrigger on Microsoft_Solutions__c (after insert, after delete) {
	Set<Id> opportunityIds = new Set<Id>();
    Switch on Trigger.operationType{
        when AFTER_INSERT {
            for (Microsoft_Solutions__c sol : Trigger.new) {
            	opportunityIds.add(sol.Opportunity__c);
        	}
        }
        when AFTER_DELETE{
            for (Microsoft_Solutions__c sol : Trigger.old) {
                opportunityIds.add(sol.Opportunity__c);
            }
        }
    }
    if (opportunityIds!=null && !opportunityIds.isEmpty()) {
        msft_OpportunityHelper.updateOpportunities(opportunityIds);
    }
}