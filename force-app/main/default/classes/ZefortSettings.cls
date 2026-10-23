public with sharing class ZefortSettings {
    public class ContactOption {
        @AuraEnabled
        public String id;

        @AuraEnabled
        public String name;

        @AuraEnabled
        public String email;

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String role;
    }

    private static final Integer CONTACT_SEARCH_LIMIT = 20;

    @AuraEnabled(cacheable=true)
    public static ContactOption getInternalSigner() {
        return getConfiguredInternalSigner();
    }

    @AuraEnabled(cacheable=true)
    public static List<ContactOption> searchContacts(String searchTerm) {
        List<ContactOption> options = new List<ContactOption>();
        String normalizedTerm = String.isBlank(searchTerm) ? null : searchTerm.trim();
        if (String.isBlank(normalizedTerm) || normalizedTerm.length() < 2) {
            return options;
        }

        String likeTerm = '%' + normalizedTerm + '%';
        for (Contact contact : [
            SELECT Id, Name, Email, Account.Name
            FROM Contact
            WHERE Email != null AND (Name LIKE :likeTerm OR Email LIKE :likeTerm)
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
            LIMIT :CONTACT_SEARCH_LIMIT
        ]) {
            options.add(toContactOption(contact));
        }
        return options;
    }

    @AuraEnabled
    public static void setInternalSigner(String contactId, String role) {
        ensureInternalSignerWritable();

        ZefortSettings__c settings = ZefortSettings__c.getOrgDefaults();
        if (settings == null || settings.Id == null) {
            settings = new ZefortSettings__c();
        }

        if (String.isBlank(contactId)) {
            settings.InternalSignerContactId__c = null;
            settings.InternalSignerRole__c = null;
            upsert settings;
            return;
        }

        ContactOption selectedContact = loadContactOption(contactId);
        if (selectedContact == null) {
            throw new AuraHandledException(
                'Internal signer must be an existing contact with an e-mail address.'
            );
        }

        settings.InternalSignerContactId__c = selectedContact.id;
        settings.InternalSignerRole__c = normalizeInternalSignerRole(role);
        upsert settings;
    }

    public static ContactOption getConfiguredInternalSigner() {
        ZefortSettings__c settings = ZefortSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.InternalSignerContactId__c)) {
            return null;
        }
        ContactOption configured = loadContactOption(settings.InternalSignerContactId__c);
        if (configured == null) {
            return null;
        }
        configured.role = normalizeInternalSignerRole(settings.InternalSignerRole__c);
        return configured;
    }

    private static ContactOption loadContactOption(String contactId) {
        Id parsedContactId = tryParseId(contactId);
        if (parsedContactId == null) {
            return null;
        }

        List<Contact> matches = [
            SELECT Id, Name, Email, Account.Name
            FROM Contact
            WHERE Id = :parsedContactId AND Email != null
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (matches.isEmpty()) {
            return null;
        }

        return toContactOption(matches[0]);
    }

    private static ContactOption toContactOption(Contact contact) {
        ContactOption option = new ContactOption();
        option.id = String.valueOf(contact.Id);
        option.name = contact.Name;
        option.email = contact.Email;
        option.label =
            (String.isBlank(contact.Name) ? '(No name)' : contact.Name) +
            ' (' +
            contact.Email +
            ')' +
            (contact.Account != null && !String.isBlank(contact.Account.Name)
                ? ' - ' + contact.Account.Name
                : '');
        return option;
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

    private static void ensureInternalSignerWritable() {
        Schema.DescribeSObjectResult objectDescribe = ZefortSettings__c.SObjectType.getDescribe();
        Schema.DescribeFieldResult internalSignerDescribe =
            ZefortSettings__c.InternalSignerContactId__c.getDescribe();
        Schema.DescribeFieldResult internalSignerRoleDescribe =
            ZefortSettings__c.InternalSignerRole__c.getDescribe();
        if (
            !objectDescribe.isAccessible() ||
            !objectDescribe.isUpdateable() ||
            !internalSignerDescribe.isAccessible() ||
            !internalSignerDescribe.isUpdateable() ||
            !internalSignerRoleDescribe.isAccessible() ||
            !internalSignerRoleDescribe.isUpdateable()
        ) {
            throw new AuraHandledException('Insufficient permissions to update Zefort settings.');
        }
    }

    private static String normalizeInternalSignerRole(String role) {
        String normalizedRole = String.isBlank(role) ? null : role.trim().toLowerCase();
        if (
            normalizedRole == 'approver' ||
            normalizedRole == 'cc'
        ) {
            return normalizedRole;
        }
        return 'signer';
    }
}