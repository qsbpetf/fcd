/*
 * Update Jira sync flag to TRUE to contacts related to closed/won opportunities e.g. contacts who have a contact role on a won opportunity
 * are synced to Jira. Actual syncing is handled by Peeklogic connectors which respect the Jira sync flag.
 * 
 * Handler is called from customOppTrigger.
 * 1) Check that opportunity is changed to closed/won from any other stage.
 * 2) Get all contact roles from opportunities that fill criteria.
 * 3) Get all corresponding contacts, update Jira sync flag to TRUE.
 *   
 * Without sharing to ensure that all related contacts' sync flag is updated regardless of current user's visibility to the contacts.
 * */
public without sharing class OpportunityTriggerHandler {
    public static final String JIRA_PROJECT_ID = '10134';
    public static final String JIRA_ISSUE_TYPE_ID = '10005';

    public static void updateContactsJiraSyncFlag(Map<Id, Opportunity> newMap, Map<Id, Opportunity> oldMap) {
        Set<Id> oppoIds = New Set<Id>();
        Set<Id> contactIds = New Set<Id>();
        List<Contact> contacts = New List<Contact>();
        List<OpportunityContactRole> contactRoles = New List<OpportunityContactRole>();

        try {
            for(Id i : newMap.keySet()) {
                if(oldMap.get(i).StageName != newMap.get(i).StageName && newMap.get(i).StageName == 'Closed won - awaiting approval') {
                    oppoIds.add(i);
                }
            }
            contactRoles = [SELECT ContactId FROM OpportunityContactRole WHERE OpportunityId IN :oppoIds];
            for(OpportunityContactRole r : contactRoles) {
                contactIds.add(r.ContactId);
            }
            if(!contactIds.isEmpty()) {
                contacts = [SELECT Id, Sync_To_Jira__c FROM Contact WHERE Sync_To_Jira__c = FALSE AND Id IN :contactIds];
            }
            for(Contact c : contacts) {
                c.Sync_To_Jira__c = true;
            }
            update contacts;
        } catch(Exception e) {
            // TODO: add Nebula logger
            system.debug(e.getCause() + ':' + e.getLineNumber() + ':' + e.getLineNumber());
        }
    }

    // Sends a Jira issue only when the batch (or a user) fills the request date on a record that has no issue yet.
    public static void createJiraIssues(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        if (!OppSplitService.isAutomationEnabled()) {
            return;
        }
        List<Opportunity> toSend = selectJiraIssueRequests(newList, oldMap);
        if (toSend.isEmpty() || Test.isRunningTest()) {
            return;
        }
        System.debug('sending: ' + toSend);
//        JCFS.API.createJiraIssueWithDefaultPostAction(JIRA_PROJECT_ID, JIRA_ISSUE_TYPE_ID, toSend, Trigger.old);
        JCFS.API.createJiraIssue(JIRA_PROJECT_ID, JIRA_ISSUE_TYPE_ID, toSend, Trigger.old);
    }

    @TestVisible
    private static List<Opportunity> selectJiraIssueRequests(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        List<Opportunity> toSend = new List<Opportunity>();
        if (newList == null || oldMap == null) {
            return toSend;
        }
        for (Opportunity opp : newList) {
            Opportunity oldOpp = oldMap.get(opp.Id);
            if (oldOpp == null) {
                continue;
            }
            if (oldOpp.Jira_Issue_Requested_On__c == null
                && opp.Jira_Issue_Requested_On__c != null
                && String.isBlank(opp.Jira_Issue_Key__c)) {
                toSend.add(opp);
            }
        }
        return toSend;
    }
}