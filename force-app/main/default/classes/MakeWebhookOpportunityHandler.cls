public without sharing class MakeWebhookOpportunityHandler {

    /** Tracks Opportunity IDs already enqueued in this transaction to avoid duplicates. */
    private static Set<Id> oppIdsAlreadyNotified = new Set<Id>();

    /** Tracks OpportunityLineItem IDs already enqueued in this transaction to avoid duplicates. */
    private static Set<Id> oliIdsAlreadyNotified = new Set<Id>();

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

            if (oppIdsAlreadyNotified.contains(oppId)) {
                continue;
            }

            if (shouldNotifyForOpportunity(newOpp, configuredStages)) {
                oppIdsToNotify.add(oppId);
                oppIdsAlreadyNotified.add(oppId);
                System.debug('--- Adding Opportunity ' + oppId + ' to notify list for Agile Day');
            }
        }

        if (oppIdsToNotify.isEmpty()) {
            return;
        }

        if (!isWebhookEnabled()) {
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

    /**
     * Handles after delete logic for OpportunityLineItem to enqueue Make.com webhook callouts
     * for deleted line items whose parent Opportunity is in a configured stage.
     */
    public static void handleOLIAfterDelete(List<OpportunityLineItem> oldList) {
        if (oldList == null || oldList.isEmpty()) {
            return;
        }

        Set<Id> oppIds = new Set<Id>();
        for (OpportunityLineItem oli : oldList) {
            if (oli.OpportunityId != null) {
                oppIds.add(oli.OpportunityId);
            }
        }

        if (oppIds.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(
            [SELECT Id, StageName, Revenue_Types_Declarative__c FROM Opportunity WHERE Id IN :oppIds]
        );
        Set<String> configuredStages = getConfiguredStages();

        if (configuredStages.isEmpty()) {
            return;
        }

        Set<Id> oliIdsToNotify = new Set<Id>();

        for (OpportunityLineItem oli : oldList) {
            if (oli.Id == null || oliIdsAlreadyNotified.contains(oli.Id)) {
                continue;
            }

            Opportunity opp = oppMap.get(oli.OpportunityId);
            if (shouldNotifyForOpportunity(opp, configuredStages)) {
                oliIdsToNotify.add(oli.Id);
                oliIdsAlreadyNotified.add(oli.Id);
                System.debug('--- Adding Opportunity Line Item ' + oli.Id + ' to notify list for Agile Day');
            }
        }

        if (oliIdsToNotify.isEmpty() || !isWebhookEnabled()) {
            return;
        }

        try {
            System.enqueueJob(new MakeOLIWebhookQueueable(oliIdsToNotify));
        } catch (Exception e) {
            System.debug('MakeWebhookOpportunityHandler error enqueuing OLI job: ' + e.getMessage());
        }
    }

    /**
     * Returns true when webhook calls are enabled via MakeWebhookSettings__c.
     * When no setting exists (null), returns true (enabled by default).
     */
    public static Boolean isWebhookEnabled() {
        MakeWebhookSettings__c s = MakeWebhookSettings__c.getInstance();
        return (s == null || s.EnableOpportunityWebhook__c != false);
    }

    /**
     * Shared eligibility rule for Opportunity-driven webhook notifications.
     * Excludes licenses because Agile Day does not support them.
     */
    private static Boolean shouldNotifyForOpportunity(Opportunity opp, Set<String> configuredStages) {
        return opp != null &&
            opp.StageName != null &&
            configuredStages != null &&
            configuredStages.contains(opp.StageName) &&
            opp.Revenue_Types_Declarative__c != null &&
            !opp.Revenue_Types_Declarative__c.equalsIgnoreCase('Licenses');
    }
}