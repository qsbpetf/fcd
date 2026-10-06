/**
 * Enforcement layer. Replaces the four NetSuite project validation rules.
 *
 * Runs "after update" on purpose: Total_Amount_Consulting__c and
 * Total_Amount_MS__c are not recalculated in Trigger.new during a before
 * trigger, so the service re-queries the saved record. addError() in an
 * after trigger still rolls the transaction back.
 *
 * A record in a guarded stage is checked only when
 *   - its stage changes into that stage, or
 *   - a required field that had a value is cleared.
 * Any other edit passes, so integrations can keep updating unrelated fields
 * and older incomplete records are not locked. Nobody can move a record into
 * a guarded stage, or empty a required field once there, without the gate.
 *
 * Users holding the Bypass_Opportunity_Readiness custom permission skip the
 * check entirely. It is meant for integration users and touches nothing else:
 * the org-wide AutomationSettings__c switch is left alone.
 */
public with sharing class OpportunityReadinessTriggerHandler {

    public static final String BYPASS_PERMISSION = 'Bypass_Opportunity_Readiness';

    @TestVisible
    private static Boolean bypass = false;

    /** Test-only stand-in for FeatureManagement.checkPermission. */
    @TestVisible
    private static Boolean bypassPermissionOverride;

    public static void handleAfterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        if (bypass || !OpportunityReadinessService.automationEnabled() || hasBypassPermission()) {
            return;
        }

        Set<String> guardedStages = new Set<String>();
        Set<String> requiredFields = new Set<String>();
        collectGuards(guardedStages, requiredFields);
        if (guardedStages.isEmpty()) {
            return;
        }

        Set<Id> candidates = new Set<Id>();
        for (Opportunity opp : newList) {
            if (opp.StageName == null || !guardedStages.contains(opp.StageName.toLowerCase())) {
                continue;
            }
            Opportunity prior = oldMap == null ? null : oldMap.get(opp.Id);
            Boolean enteringStage = prior == null || prior.StageName != opp.StageName;
            if (enteringStage || clearedARequiredField(opp, prior, requiredFields)) {
                candidates.add(opp.Id);
            }
        }
        if (candidates.isEmpty()) {
            return;
        }

        Map<Id, OpportunityReadinessService.Result> results =
            OpportunityReadinessService.evaluate(candidates, null);

        for (Opportunity opp : newList) {
            OpportunityReadinessService.Result r = results.get(opp.Id);
            if (r != null && !r.isReady) {
                opp.addError(r.errorMessage(), false);
            }
        }
    }

    private static Boolean hasBypassPermission() {
        if (bypassPermissionOverride != null) {
            return bypassPermissionOverride;
        }
        return FeatureManagement.checkPermission(BYPASS_PERMISSION);
    }

    /** Stages that block, and every field those blocking rules require. */
    private static void collectGuards(Set<String> stages, Set<String> fields) {
        for (Opportunity_Readiness_Rule__mdt rule : OpportunityReadinessService.rules()) {
            if (rule.Severity__c == 'Warning' || String.isBlank(rule.Target_Stages__c)) {
                continue;
            }
            for (String s : rule.Target_Stages__c.split(';')) {
                if (String.isNotBlank(s)) {
                    stages.add(s.trim().toLowerCase());
                }
            }
            if (String.isNotBlank(rule.Required_Fields__c)) {
                for (String f : rule.Required_Fields__c.split(';')) {
                    if (String.isNotBlank(f)) {
                        fields.add(f.trim());
                    }
                }
            }
        }
    }

    /** True when a required field had a value before this save and is now empty. */
    @TestVisible
    private static Boolean clearedARequiredField(Opportunity opp, Opportunity prior, Set<String> fields) {
        if (prior == null) {
            return false;
        }
        for (String f : fields) {
            Object before;
            Object after;
            try {
                before = prior.get(f);
                after = opp.get(f);
            } catch (SObjectException e) {
                continue;
            }
            if (!isBlank(before) && isBlank(after)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean isBlank(Object value) {
        if (value == null) {
            return true;
        }
        if (value instanceof String) {
            return String.isBlank((String) value);
        }
        return false;
    }
}