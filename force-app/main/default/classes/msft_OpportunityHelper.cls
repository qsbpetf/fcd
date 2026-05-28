public with sharing class msft_OpportunityHelper {
    
    public static void updateOpportunities(Set<Id> opportunityIds) {
        if (opportunityIds.isEmpty()) return;
        Map<Id, Integer> solutionCounts = new Map<Id, Integer>();

        for (AggregateResult ar : [SELECT Opportunity__c Id, COUNT(Id) solutionCount
                                   FROM Microsoft_Solutions__c
                                   WHERE Opportunity__c IN :opportunityIds
                                   GROUP BY Opportunity__c
                                  ]) {
                                      system.debug('solutionCount-->'+(Integer) ar.get('solutionCount'));
                                      solutionCounts.put((Id) ar.get('Id'), (Integer) ar.get('solutionCount'));
                                  }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Id oppId : opportunityIds) {
            Opportunity opp = new Opportunity(Id = oppId);
            if(solutionCounts.get(oppId)==null || solutionCounts.get(oppId)==0){
                opp.Sync_With_Partner_Center__c=false;
                opp.Solution_Count__c=0;
            }
            else
                opp.Solution_Count__c = solutionCounts.get(oppId);
            
            opportunitiesToUpdate.add(opp);
        }

        if (opportunitiesToUpdate!=null && !opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate;
        }
    }
}