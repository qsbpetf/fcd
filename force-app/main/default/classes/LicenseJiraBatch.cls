public without sharing class LicenseJiraBatch implements Database.Batchable<SObject> {
    public static final Integer WINDOW_DAYS = 90;
    public static final Integer BATCH_SIZE = 10;
    public static final Date NOT_BEFORE = Date.newInstance(2026, 10, 12);

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date windowEnd = Date.today().addDays(WINDOW_DAYS);
        Id opportunityId = '006S800000SLp4FIAT';

        return Database.getQueryLocator([
            SELECT Id, Jira_Issue_Requested_On__c
            FROM Opportunity
            WHERE StageName IN ('Closed won - awaiting approval', 'Order')
            AND Jira_Issue_Key__c = NULL
            AND Jira_Issue_Requested_On__c = NULL
            AND Id = :opportunityId
            AND Id IN (
                SELECT OpportunityId
                FROM OpportunityLineItem
                WHERE Unit_of_Measure__c = 'License'
                AND License_end_date__c != NULL
                AND License_end_date__c >= :NOT_BEFORE
                AND License_end_date__c <= :windowEnd
            )
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        Datetime requestedOn = System.now();
        List<Opportunity> toStamp = new List<Opportunity>();
        for (Opportunity opp : (List<Opportunity>) scope) {
            opp.Jira_Issue_Requested_On__c = requestedOn;
            toStamp.add(opp);
        }

        update toStamp;
    }

    public void finish(Database.BatchableContext bc) {
    }
}