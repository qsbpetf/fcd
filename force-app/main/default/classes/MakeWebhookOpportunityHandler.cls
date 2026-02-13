public without sharing class MakeWebhookOpportunityHandler {

    /**
     * Handles after update logic for Opportunity to enqueue Make.com webhook callouts
     * when the Opportunity stage changes to a configured value.
     */
    public static void handleAfterUpdate(Map<Id, Opportunity> newMap, Map<Id, Opportunity> oldMap) {
        if (newMap == null || newMap.isEmpty() || oldMap == null || oldMap.isEmpty()) {
            return;
        }

        Set<String> configuredStages = getConfiguredStages();
        if (configuredStages.isEmpty()) {
            return;
        }

        Set<Id> oppIdsToNotify = new Set<Id>();

        for (Id oppId : newMap.keySet()) {
            Opportunity newOpp = newMap.get(oppId);

            if (newOpp == null) {
                continue;
            }

            // Trigger whenever the Opportunity is in a configured stage,
            // regardless of whether the stage value itself changed.
            if (newOpp.StageName != null &&
                configuredStages.contains(newOpp.StageName)) {
                oppIdsToNotify.add(oppId);
                System.debug('--- Adding Opportunity ' + oppId + ' to notify list for Agile Day');
            }
        }

        if (oppIdsToNotify.isEmpty()) {
            return;
        }

        try {
            System.enqueueJob(new MakeOpportunityWebhookQueueable(new List<Id>(oppIdsToNotify)));
        } catch (Exception e) {
            // Keep simple logging to avoid adding new dependencies
            System.debug('MakeWebhookOpportunityHandler error enqueuing job: ' + e.getMessage());
        }
    }

    /**
     * Loads all active stage names from MakeWebhookOpportunityStageConfig__mdt.
     * When running in test context, only records with IsTestRecord__c = true are used;
     * otherwise only records with IsTestRecord__c = false or null are used.
     */
    public static Set<String> getConfiguredStages() {
        Set<String> stages = new Set<String>();
        List<MakeWebhookOpportunityStageConfig__mdt> configs;

        if (Test.isRunningTest()) {
            configs = [
                SELECT StageName__c
                FROM MakeWebhookOpportunityStageConfig__mdt
                WHERE IsActive__c = TRUE AND IsTestRecord__c = TRUE
            ];
        } else {
            configs = [
                SELECT StageName__c
                FROM MakeWebhookOpportunityStageConfig__mdt
                WHERE IsActive__c = TRUE AND (IsTestRecord__c = FALSE OR IsTestRecord__c = NULL)
            ];
        }

        for (MakeWebhookOpportunityStageConfig__mdt config : configs) {
            if (String.isNotBlank(config.StageName__c)) {
                stages.add(config.StageName__c);
            }
        }

        return stages;
    }
}

