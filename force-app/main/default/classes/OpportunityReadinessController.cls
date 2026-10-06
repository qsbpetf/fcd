/**
 * LWC entry point for the readiness panel and the "Close Opportunity" modal.
 */
public with sharing class OpportunityReadinessController {

    /**
     * @param recordId Opportunity to check.
     * @param targetStage Stage the user is heading for. Null = current stage.
     */
    @AuraEnabled(cacheable=false)
    public static OpportunityReadinessService.Result check(Id recordId, String targetStage) {
        try {
            return OpportunityReadinessService.evaluateOne(recordId, targetStage);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Stage picklist values, so the modal can offer the closing stages. */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> closingStages() {
        List<Map<String, String>> out = new List<Map<String, String>>();
        Set<String> wanted = new Set<String>();
        for (Opportunity_Readiness_Rule__mdt rule : OpportunityReadinessService.rules()) {
            if (String.isBlank(rule.Target_Stages__c)) {
                continue;
            }
            for (String s : rule.Target_Stages__c.split(';')) {
                wanted.add(s.trim().toLowerCase());
            }
        }
        for (Schema.PicklistEntry entry : Opportunity.StageName.getDescribe().getPicklistValues()) {
            if (entry.isActive() && wanted.contains(entry.getValue().toLowerCase())) {
                out.add(new Map<String, String>{
                    'value' => entry.getValue(),
                    'label' => entry.getLabel()
                });
            }
        }
        return out;
    }

    /**
     * Writes the fields the user filled in and moves the stage in one DML,
     * so the enforcement trigger sees a complete record.
     */
    @AuraEnabled
    public static OpportunityReadinessService.Result saveAndAdvance(
        Id recordId,
        Map<String, Object> fieldValues,
        String targetStage
    ) {
        try {
            Opportunity opp = new Opportunity(Id = recordId);
            Map<String, Schema.SObjectField> fieldMap =
                Opportunity.SObjectType.getDescribe().fields.getMap();

            if (fieldValues != null) {
                for (String apiName : fieldValues.keySet()) {
                    Schema.SObjectField token = fieldMap.get(apiName.toLowerCase());
                    if (token == null) {
                        continue;
                    }
                    Schema.DescribeFieldResult dfr = token.getDescribe();
                    if (!dfr.isUpdateable()) {
                        throw new AuraHandledException(
                            'You do not have edit access to ' + dfr.getLabel() + '.'
                        );
                    }
                    opp.put(dfr.getName(), coerce(fieldValues.get(apiName), dfr.getType()));
                }
            }
            if (String.isNotBlank(targetStage)) {
                opp.StageName = targetStage;
            }
            update opp;
            return OpportunityReadinessService.evaluateOne(recordId, targetStage);
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Object coerce(Object value, Schema.DisplayType type) {
        if (value == null || (value instanceof String && String.isBlank((String) value))) {
            return null;
        }
        String s = String.valueOf(value);
        switch on type {
            when DATE {
                return Date.valueOf(s.substringBefore('T'));
            }
            when DATETIME {
                return (Datetime) JSON.deserialize('"' + s + '"', Datetime.class);
            }
            when CURRENCY, DOUBLE, PERCENT {
                return Decimal.valueOf(s);
            }
            when INTEGER {
                return Integer.valueOf(s);
            }
            when BOOLEAN {
                return Boolean.valueOf(s);
            }
            when else {
                return s;
            }
        }
    }
}