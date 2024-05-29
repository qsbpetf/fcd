/*
 * Update Jira sync flag to TRUE to contacts who are added as a contact role to a closed/won opportunity.
 * Flagged contacts are synced to Jira. Actual syncing is handled by Peeklogic connectors which respect the Jira sync flag.
 * 
 * TODO: create handler
 * */
trigger OpportunityContactRoleTrigger on OpportunityContactRole (after insert) {
    Map<Id, Id> contactIdMap = New Map<Id, Id>();
    Set<Id> opportunityIds = New Set<Id>();
    Set<Id> contactIds = New Set<Id>();
    List<Contact> contacts = New List<Contact>();
    Map<Id, Opportunity> opportunities;
    
    try {
        For(OpportunityContactRole role : Trigger.new) {
            opportunityIds.add(role.OpportunityId);
            contactIdMap.put(role.OpportunityId, role.ContactId);
        }
        
        opportunities = New Map<Id, Opportunity>([SELECT Id, StageName FROM Opportunity WHERE Id IN :opportunityIds]);
        For(OpportunityContactRole role : Trigger.new) {	
            if(opportunities.get(role.OpportunityId).StageName == 'Closed won - awaiting approval' || opportunities.get(role.OpportunityId).StageName == 'Order') {
                contactIds.add(role.ContactId);
            }
        }
    
        contacts = [SELECT Id, Sync_To_Jira__c FROM Contact WHERE ID IN :contactIds AND Sync_To_Jira__c = FALSE];
        for(Contact c : contacts) {
            c.Sync_To_Jira__c = true;
        }
        update contacts;
    } catch(Exception e) {
        // TODO: add Nebula logger
        system.debug(e.getCause() + ':' + e.getLineNumber() + ':' + e.getLineNumber());
    }
}