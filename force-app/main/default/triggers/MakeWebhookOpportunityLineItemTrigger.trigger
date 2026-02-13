trigger MakeWebhookOpportunityLineItemTrigger on OpportunityLineItem (after delete) {
    if (Trigger.isAfter && Trigger.isDelete) {
        Set<Id> oliIdsToNotify = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();

        // Collect parent opportunity IDs from deleted line items
        for (OpportunityLineItem oli : Trigger.old) {
            if (oli.OpportunityId != null) {
                oppIds.add(oli.OpportunityId);
            }
        }

        if (!oppIds.isEmpty()) {
            // Load parent opportunities and configured stages
            Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
                [SELECT Id, StageName FROM Opportunity WHERE Id IN :oppIds]
            );
            Set<String> configuredStages = MakeWebhookOpportunityHandler.getConfiguredStages();

            if (!configuredStages.isEmpty()) {
                // Only include line items whose parent Opportunity has a configured stage
                for (OpportunityLineItem oli : Trigger.old) {
                    Opportunity opp = oppMap.get(oli.OpportunityId);
                    if (oli.Id != null &&
                        opp != null &&
                        configuredStages.contains(opp.StageName)) {
                        oliIdsToNotify.add(oli.Id);
                        System.debug('--- Adding Opportunity Line Item ' + oli.Id + ' to notify list for Agile Day');
                    }
                }
            }
        }

        if (!oliIdsToNotify.isEmpty() && MakeWebhookOpportunityHandler.isWebhookEnabled()) {
            System.enqueueJob(new MakeOLIWebhookQueueable(oliIdsToNotify));
        }
    }
}

