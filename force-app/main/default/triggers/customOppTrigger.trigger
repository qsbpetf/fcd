trigger customOppTrigger on Opportunity (after insert, after update) {
 integrator_da__.RealTimeExportResult res = integrator_da__.RealTimeExporter.processExport();
 if(Trigger.isAfter && Trigger.isUpdate) {
    OpportunityTriggerHandler.updateContactsJiraSyncFlag(Trigger.newMap, Trigger.oldMap);
 } 
}