/**
 * Evaluates Opportunity_Readiness_Rule__mdt against Opportunities.
 *
 * One evaluation engine, three consumers:
 *   - OpportunityReadinessController  -> readiness panel + modal (UX)
 *   - OpportunityReadinessTriggerHandler -> hard block on save (enforcement)
 *   - tests
 *
 * Always re-queries the Opportunity. Formula and roll-up fields such as
 * Total_Amount_Consulting__c are not recalculated in Trigger.new, so the
 * trigger runs "after update" and this class reads the saved values back.
 */
public with sharing class OpportunityReadinessService {

    private static final String SUBSIDIARY_ACCOUNT_FIELD = 'Account.CV_Subsidiary__c';
    // Spelled "Subsiduary" on Opportunity: that is the real API name in this
    // org, not a typo here. The Account field is spelled correctly.
    private static final String SUBSIDIARY_OPP_FIELD = 'CV_Subsiduary__c';
    private static final String EXTENSION_VALUE = 'Extension (Use Existing Project in NS)';
    private static final String EXTENSION_FIELD = 'New_or_Extension__c';

    // ---------------------------------------------------------------- results

    public class FieldGap {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public Boolean required = true;
        public FieldGap(String apiName, String label) {
            this.apiName = apiName;
            this.label = label;
        }
    }

    public class RuleGap {
        @AuraEnabled public String ruleName;
        @AuraEnabled public String ruleLabel;
        @AuraEnabled public String severity;
        @AuraEnabled public String message;
        @AuraEnabled public String guidance;
        @AuraEnabled public List<FieldGap> missingFields = new List<FieldGap>();
    }

    public class Result {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String targetStage;
        @AuraEnabled public Boolean isReady = true;
        @AuraEnabled public List<RuleGap> blocking = new List<RuleGap>();
        @AuraEnabled public List<RuleGap> warnings = new List<RuleGap>();
        /** Deduplicated field list to render in the edit form, in rule order. */
        @AuraEnabled public List<FieldGap> fieldsToFill = new List<FieldGap>();
        /** Distinct fields every in-scope rule asks for. */
        @AuraEnabled public Integer requiredFieldCount = 0;
        /** Of those, how many already have a value. */
        @AuraEnabled public Integer filledFieldCount = 0;

        public String errorMessage() {
            List<String> parts = new List<String>();
            for (RuleGap g : blocking) {
                parts.add(g.message);
            }
            return String.join(parts, '\n');
        }
    }

    // ---------------------------------------------------------------- rules

    @TestVisible
    private static List<Opportunity_Readiness_Rule__mdt> ruleOverride;

    public static List<Opportunity_Readiness_Rule__mdt> rules() {
        if (ruleOverride != null) {
            return ruleOverride;
        }
        return [
            SELECT DeveloperName, MasterLabel, Active__c, Sequence__c, Severity__c,
                   Target_Stages__c, Netsuite_Record_Type__c,
                   Effective_Date_Field__c, Effective_From__c,
                   Treat_Blank_Effective_Date_As_In_Scope__c,
                   Primary_Amount_Field__c, Primary_Amount_Operator__c,
                   Secondary_Amount_Field__c, Secondary_Amount_Operator__c,
                   Amount_Match__c,
                   Subsidiary_Scope__c, Subsidiary_Source__c,
                   Skip_When_Extension__c, Required_Fields__c,
                   Error_Message__c, Guidance__c
            FROM Opportunity_Readiness_Rule__mdt
            WHERE Active__c = true
            ORDER BY Sequence__c NULLS LAST, DeveloperName
        ];
    }

    // ---------------------------------------------------------------- entry points

    /**
     * @param recordIds Opportunities to evaluate.
     * @param stageOverride Evaluate as if the record were already at this stage.
     *        Pass null to use each record's current stage.
     */
    public static Map<Id, Result> evaluate(Set<Id> recordIds, String stageOverride) {
        Map<Id, Result> results = new Map<Id, Result>();
        if (recordIds == null || recordIds.isEmpty()) {
            return results;
        }
        List<Opportunity_Readiness_Rule__mdt> allRules = rules();
        Map<Id, Opportunity> opps = queryOpportunities(recordIds, allRules);

        for (Id recordId : recordIds) {
            Opportunity opp = opps.get(recordId);
            Result r = new Result();
            r.recordId = recordId;
            if (opp == null) {
                results.put(recordId, r);
                continue;
            }
            r.targetStage = String.isBlank(stageOverride) ? opp.StageName : stageOverride;

            Set<String> seenFields = new Set<String>();
            Set<String> allRequired = new Set<String>();
            for (Opportunity_Readiness_Rule__mdt rule : allRules) {
                if (!inScope(rule, opp, r.targetStage)) {
                    continue;
                }
                if (String.isNotBlank(rule.Required_Fields__c)) {
                    for (String f : rule.Required_Fields__c.split(';')) {
                        if (String.isNotBlank(f)) {
                            allRequired.add(f.trim().toLowerCase());
                        }
                    }
                }
                List<FieldGap> missing = missingFields(rule, opp);
                if (missing.isEmpty()) {
                    continue;
                }
                RuleGap gap = new RuleGap();
                gap.ruleName = rule.DeveloperName;
                gap.ruleLabel = rule.MasterLabel;
                gap.severity = rule.Severity__c;
                gap.message = rule.Error_Message__c;
                gap.guidance = rule.Guidance__c;
                gap.missingFields = missing;

                if (rule.Severity__c == 'Warning') {
                    r.warnings.add(gap);
                } else {
                    r.blocking.add(gap);
                    r.isReady = false;
                }
                for (FieldGap f : missing) {
                    if (seenFields.add(f.apiName)) {
                        r.fieldsToFill.add(f);
                    }
                }
            }
            r.requiredFieldCount = allRequired.size();
            r.filledFieldCount = allRequired.size() - r.fieldsToFill.size();
            results.put(recordId, r);
        }
        return results;
    }

    public static Result evaluateOne(Id recordId, String stageOverride) {
        Map<Id, Result> m = evaluate(new Set<Id>{ recordId }, stageOverride);
        return m.containsKey(recordId) ? m.get(recordId) : new Result();
    }

    // ---------------------------------------------------------------- scoping

    private static Boolean inScope(Opportunity_Readiness_Rule__mdt rule, Opportunity opp, String stage) {
        // Stage
        if (String.isNotBlank(rule.Target_Stages__c)) {
            Boolean stageMatch = false;
            for (String s : rule.Target_Stages__c.split(';')) {
                if (s.trim().equalsIgnoreCase(stage)) {
                    stageMatch = true;
                    break;
                }
            }
            if (!stageMatch) {
                return false;
            }
        }
        // NetSuite record type
        if (String.isNotBlank(rule.Netsuite_Record_Type__c)) {
            String rt = str(readField(opp, 'Netsuite_Record_Type__c'));
            if (rt == null || !rt.equalsIgnoreCase(rule.Netsuite_Record_Type__c)) {
                return false;
            }
        }
        // Effective-from cutoff
        if (rule.Effective_From__c != null && String.isNotBlank(rule.Effective_Date_Field__c)) {
            Object raw = readField(opp, rule.Effective_Date_Field__c);
            Date effective = toDate(raw);
            if (effective == null) {
                if (rule.Treat_Blank_Effective_Date_As_In_Scope__c != true) {
                    return false;
                }
            } else if (effective < rule.Effective_From__c) {
                return false;
            }
        }
        // Amounts
        if (!amountsMatch(opp, rule)) {
            return false;
        }
        // Subsidiary
        if (!subsidiaryMatches(opp, rule)) {
            return false;
        }
        // Extension opt-out
        if (rule.Skip_When_Extension__c == true) {
            String ext = str(readField(opp, EXTENSION_FIELD));
            if (ext != null && ext.equalsIgnoreCase(EXTENSION_VALUE)) {
                return false;
            }
        }
        return true;
    }

    /**
     * Combines the configured amount conditions. "All" (the default) needs
     * every one to hold; "Any" needs at least one, so a single rule can cover
     * consulting OR managed services.
     */
    private static Boolean amountsMatch(Opportunity opp, Opportunity_Readiness_Rule__mdt rule) {
        List<Boolean> checks = new List<Boolean>();
        if (isConfigured(rule.Primary_Amount_Field__c, rule.Primary_Amount_Operator__c)) {
            checks.add(amountMatches(opp, rule.Primary_Amount_Field__c, rule.Primary_Amount_Operator__c));
        }
        if (isConfigured(rule.Secondary_Amount_Field__c, rule.Secondary_Amount_Operator__c)) {
            checks.add(amountMatches(opp, rule.Secondary_Amount_Field__c, rule.Secondary_Amount_Operator__c));
        }
        if (checks.isEmpty()) {
            return true;
        }
        if (rule.Amount_Match__c == 'Any') {
            return checks.contains(true);
        }
        return !checks.contains(false);
    }

    private static Boolean isConfigured(String fieldName, String operator) {
        return String.isNotBlank(fieldName) && String.isNotBlank(operator) && operator != 'Any';
    }

    private static Boolean amountMatches(Opportunity opp, String fieldName, String operator) {
        if (String.isBlank(fieldName) || String.isBlank(operator) || operator == 'Any') {
            return true;
        }
        Decimal value = toDecimal(readField(opp, fieldName));
        if (value == null) {
            value = 0;
        }
        if (operator == 'GreaterThanZero') {
            return value > 0;
        }
        if (operator == 'EqualsZero') {
            return value == 0;
        }
        return true;
    }

    private static Boolean subsidiaryMatches(Opportunity opp, Opportunity_Readiness_Rule__mdt rule) {
        if (String.isBlank(rule.Subsidiary_Scope__c) || rule.Subsidiary_Scope__c == 'Any') {
            return true;
        }
        Boolean isUkUs;
        if (rule.Subsidiary_Source__c == 'Opportunity') {
            String value = str(readField(opp, SUBSIDIARY_OPP_FIELD));
            value = value == null ? '' : value;
            isUkUs = value.containsIgnoreCase('UK') || value.containsIgnoreCase('US');
        } else {
            String value = opp.Account == null ? null : str(opp.Account.get('CV_Subsidiary__c'));
            value = value == null ? '' : value;
            isUkUs = value.equalsIgnoreCase('UK') || value.equalsIgnoreCase('US');
        }
        return rule.Subsidiary_Scope__c == 'UK_US' ? isUkUs : !isUkUs;
    }

    // ---------------------------------------------------------------- field gaps

    private static List<FieldGap> missingFields(Opportunity_Readiness_Rule__mdt rule, Opportunity opp) {
        List<FieldGap> gaps = new List<FieldGap>();
        if (String.isBlank(rule.Required_Fields__c)) {
            return gaps;
        }
        Map<String, Schema.SObjectField> fieldMap = Opportunity.SObjectType.getDescribe().fields.getMap();
        for (String raw : rule.Required_Fields__c.split(';')) {
            String apiName = raw.trim();
            if (String.isBlank(apiName)) {
                continue;
            }
            if (!isBlankValue(readField(opp, apiName))) {
                continue;
            }
            Schema.SObjectField token = fieldMap.get(apiName.toLowerCase());
            String label = token == null ? apiName : token.getDescribe().getLabel();
            gaps.add(new FieldGap(apiName, label));
        }
        return gaps;
    }

    private static Boolean isBlankValue(Object value) {
        if (value == null) {
            return true;
        }
        if (value instanceof String) {
            return String.isBlank((String) value);
        }
        return false;
    }

    // ---------------------------------------------------------------- query

    private static Map<Id, Opportunity> queryOpportunities(Set<Id> recordIds, List<Opportunity_Readiness_Rule__mdt> allRules) {
        Set<String> fields = new Set<String>{
            'Id', 'StageName', 'AccountId', SUBSIDIARY_ACCOUNT_FIELD, EXTENSION_FIELD
        };
        Map<String, Schema.SObjectField> fieldMap = Opportunity.SObjectType.getDescribe().fields.getMap();
        for (Opportunity_Readiness_Rule__mdt rule : allRules) {
            addField(fields, fieldMap, rule.Netsuite_Record_Type__c == null ? null : 'Netsuite_Record_Type__c');
            addField(fields, fieldMap, rule.Effective_Date_Field__c);
            addField(fields, fieldMap, rule.Primary_Amount_Field__c);
            addField(fields, fieldMap, rule.Secondary_Amount_Field__c);
            if (rule.Subsidiary_Source__c == 'Opportunity') {
                addField(fields, fieldMap, SUBSIDIARY_OPP_FIELD);
            }
            if (String.isNotBlank(rule.Required_Fields__c)) {
                for (String f : rule.Required_Fields__c.split(';')) {
                    addField(fields, fieldMap, f);
                }
            }
        }
        String soql = 'SELECT ' + String.join(new List<String>(fields), ', ') +
                      ' FROM Opportunity WHERE Id IN :recordIds';
        return new Map<Id, Opportunity>((List<Opportunity>) Database.query(soql));
    }

    private static void addField(Set<String> fields, Map<String, Schema.SObjectField> fieldMap, String apiName) {
        if (String.isBlank(apiName)) {
            return;
        }
        String trimmed = apiName.trim();
        if (fieldMap.containsKey(trimmed.toLowerCase())) {
            fields.add(trimmed);
        }
    }

    // ---------------------------------------------------------------- value helpers

    private static Object readField(SObject record, String apiName) {
        if (record == null || String.isBlank(apiName)) {
            return null;
        }
        try {
            return record.get(apiName.trim());
        } catch (SObjectException e) {
            return null;
        }
    }

    private static String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Decimal toDecimal(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Decimal) {
            return (Decimal) value;
        }
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception e) {
            return null;
        }
    }

    private static Date toDate(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Date) {
            return (Date) value;
        }
        if (value instanceof Datetime) {
            return ((Datetime) value).date();
        }
        try {
            return Date.valueOf(String.valueOf(value));
        } catch (Exception e) {
            return null;
        }
    }

    // ---------------------------------------------------------------- kill switches

    /**
     * Test-only override. Tests must not flip the real custom settings: that
     * switch gates every validation rule in the org, so turning it on inside a
     * test activates unrelated rules and breaks the test for the wrong reason.
     */
    @TestVisible
    private static Boolean automationOverride;

    /** Mirrors the two $Setup checks the original validation rules used. */
    public static Boolean automationEnabled() {
        if (automationOverride != null) {
            return automationOverride;
        }
        Boolean orgSwitch = AutomationSettings__c.getInstance() != null
            && AutomationSettings__c.getInstance().Validation_Rule_Enabled__c == true;
        Boolean rollupSwitch = rh2__PS_Settings__c.getInstance() != null
            && rh2__PS_Settings__c.getInstance().rh2__Run_Validation_Rule__c == true;
        return orgSwitch && rollupSwitch;
    }
}