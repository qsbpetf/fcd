public with sharing class ZefortParticipantPrefillService {
    private class ContextRule {
        public String contactPath;
        public String defaultRole;
        public Decimal priority;

        public ContextRule(String contactPath, String defaultRole, Decimal priority) {
            this.contactPath = contactPath;
            this.defaultRole = defaultRole;
            this.priority = priority;
        }
    }

    public class PrefillParticipant {
        @AuraEnabled
        public String contactId;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public String email;

        @AuraEnabled
        public String role;

        @AuraEnabled
        public String source;

        public PrefillParticipant(
            String contactId,
            String role,
            String source
        ) {
            this.contactId = contactId;
            this.role = ZefortRoleUtil.normalizeRole(role);
            this.source = source;
            this.name = null;
            this.email = null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PrefillParticipant> getPrefilledParticipants(String recordId, String objectApiName) {
        Map<String, PrefillParticipant> prefillsByContact = new Map<String, PrefillParticipant>();
        if (String.isBlank(recordId)) {
            return new List<PrefillParticipant>();
        }

        ZefortRecordResolver.ResolutionResult resolution = ZefortRecordResolver.resolveRecordContext(
            recordId,
            objectApiName
        );
        if (resolution == null || !resolution.success || String.isBlank(resolution.accountId)) {
            return new List<PrefillParticipant>();
        }

        addContextRulePrefills(prefillsByContact, recordId, resolution.objectApiName);
        enrichFromContacts(prefillsByContact);

        return new List<PrefillParticipant>(prefillsByContact.values());
    }

    private static void addContextRulePrefills(
        Map<String, PrefillParticipant> prefillsByContact,
        String recordId,
        String objectApiName
    ) {
        List<ContextRule> rules = getContextRules(objectApiName);
        if (rules.isEmpty()) {
            return;
        }

        Set<String> contactPaths = new Set<String>();
        for (ContextRule rule : rules) {
            if (!String.isBlank(rule.contactPath)) {
                contactPaths.add(rule.contactPath);
            }
        }
        if (contactPaths.isEmpty()) {
            return;
        }

        Map<String, String> resolvedValues = ZefortRecordResolver.resolvePathValues(
            recordId,
            objectApiName,
            new List<String>(contactPaths)
        );
        for (ContextRule rule : rules) {
            String contactId = resolvedValues.get(rule.contactPath);
            if (String.isBlank(contactId)) {
                continue;
            }

            contactId = contactId.trim();
            if (!prefillsByContact.containsKey(contactId)) {
                prefillsByContact.put(
                    contactId,
                    new PrefillParticipant(contactId, rule.defaultRole, 'context_rule')
                );
            }
        }
    }

    private static List<ContextRule> getContextRules(String objectApiName) {
        if (objectApiName == 'Contact') {
            return new List<ContextRule>{new ContextRule('Id', 'signer', 10)};
        }
        if (objectApiName == 'Case') {
            return new List<ContextRule>{new ContextRule('ContactId', 'signer', 20)};
        }

        List<ContextRule> rules = new List<ContextRule>();
        for (Zefort_Signer_Prefill_Rule__mdt rule : [
            SELECT Contact_Path__c, Default_Role__c, Priority__c
            FROM Zefort_Signer_Prefill_Rule__mdt
            WHERE Active__c = true AND Object_Api_Name__c = :objectApiName
            ORDER BY Priority__c ASC, DeveloperName ASC
        ]) {
            rules.add(new ContextRule(rule.Contact_Path__c, rule.Default_Role__c, rule.Priority__c));
        }
        return rules;
    }

    private static void enrichFromContacts(Map<String, PrefillParticipant> prefillsByContact) {
        if (prefillsByContact.isEmpty()) {
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        for (String contactId : prefillsByContact.keySet()) {
            Id parsedId = tryParseId(contactId);
            if (parsedId != null) {
                contactIds.add(parsedId);
            }
        }
        if (contactIds.isEmpty()) {
            return;
        }

        for (Contact contact : [
            SELECT Id, Name, Email
            FROM Contact
            WHERE Id IN :contactIds
            WITH SECURITY_ENFORCED
        ]) {
            String key = String.valueOf(contact.Id);
            if (!prefillsByContact.containsKey(key)) {
                continue;
            }
            PrefillParticipant participant = prefillsByContact.get(key);
            participant.name = String.isBlank(participant.name) ? contact.Name : participant.name;
            participant.email = String.isBlank(participant.email) ? contact.Email : participant.email;
        }
    }

    private static Id tryParseId(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id) value;
        } catch (Exception e) {
            return null;
        }
    }

}