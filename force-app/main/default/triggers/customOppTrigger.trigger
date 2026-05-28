trigger customOppTrigger on Opportunity (after insert, after update) {
    integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport();

    if (Trigger.isAfter && Trigger.isUpdate) {
        OpportunityTriggerHandler.updateContactsJiraSyncFlag(Trigger.newMap, Trigger.oldMap);
        MakeWebhookOpportunityHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
    }

    // Opportunity Splits automation (migrated from flows).
    if (Trigger.isAfter) {
        if (OppSplitService.isAutomationEnabled() && OppSplitService.tryEnterAutomation()) {
            OppSplitEngine.execute(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
        }
    }
}