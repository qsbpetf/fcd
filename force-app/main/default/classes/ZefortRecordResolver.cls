public with sharing class ZefortRecordResolver {
    public class ResolutionResult {
        @AuraEnabled
        public Boolean success;

        @AuraEnabled
        public String objectApiName;

        @AuraEnabled
        public String accountId;

        @AuraEnabled
        public String contextContactId;

        @AuraEnabled
        public String message;

        public ResolutionResult() {
            this.success = false;
            this.message = '';
        }
    }

    private class RuleConfig {
        public String accountPath;
        public String contactPath;

        public RuleConfig(String accountPath, String contactPath) {
            this.accountPath = accountPath;
            this.contactPath = contactPath;
        }
    }

    @AuraEnabled(cacheable=true)
    public static ResolutionResult resolveRecordContext(String recordId, String objectApiName) {
        ResolutionResult result = new ResolutionResult();
        if (String.isBlank(recordId)) {
            result.message = 'Record ID is required.';
            return result;
        }

        String resolvedObjectApiName = String.isBlank(objectApiName)
            ? inferObjectApiName(recordId)
            : objectApiName;
        if (String.isBlank(resolvedObjectApiName)) {
            result.message = 'Unable to determine source object.';
            return result;
        }

        result.objectApiName = resolvedObjectApiName;
        RuleConfig config = getRuleConfig(resolvedObjectApiName);
        if (config == null || String.isBlank(config.accountPath)) {
            result.message = 'No active account resolver configuration found.';
            return result;
        }

        try {
            Set<String> fieldsToSelect = new Set<String>{config.accountPath};
            if (!String.isBlank(config.contactPath)) {
                fieldsToSelect.add(config.contactPath);
            }

            SObject sourceRecord = loadSourceRecord(resolvedObjectApiName, recordId, fieldsToSelect);
            Object accountValue = valueForPath(sourceRecord, config.accountPath);
            result.accountId = accountValue == null ? null : String.valueOf(accountValue);

            if (!String.isBlank(config.contactPath)) {
                Object contactValue = valueForPath(sourceRecord, config.contactPath);
                result.contextContactId = contactValue == null ? null : String.valueOf(contactValue);
            }

            if (String.isBlank(result.accountId)) {
                result.message = 'Could not resolve account for source record.';
                return result;
            }

            result.success = true;
            result.message = '';
            return result;
        } catch (Exception e) {
            result.message = 'Failed to resolve source record context: ' + e.getMessage();
            return result;
        }
    }

    public static Map<String, String> resolvePathValues(
        String recordId,
        String objectApiName,
        List<String> fieldPaths
    ) {
        Map<String, String> values = new Map<String, String>();
        if (String.isBlank(recordId) || String.isBlank(objectApiName) || fieldPaths == null) {
            return values;
        }

        Set<String> safePaths = new Set<String>();
        for (String path : fieldPaths) {
            if (String.isBlank(path) || !isSafeFieldPath(path)) {
                continue;
            }
            safePaths.add(path);
        }
        if (safePaths.isEmpty()) {
            return values;
        }

        try {
            SObject sourceRecord = loadSourceRecord(objectApiName, recordId, safePaths);
            for (String path : safePaths) {
                Object value = valueForPath(sourceRecord, path);
                if (value != null) {
                    values.put(path, String.valueOf(value));
                }
            }
        } catch (Exception e) {
            System.debug('Error resolving path values: ' + e.getMessage());
        }

        return values;
    }

    private static RuleConfig getRuleConfig(String objectApiName) {
        if (objectApiName == 'Account') {
            return new RuleConfig('Id', null);
        }
        if (objectApiName == 'Opportunity') {
            return new RuleConfig('AccountId', null);
        }
        if (objectApiName == 'Contact') {
            return new RuleConfig('AccountId', 'Id');
        }
        if (objectApiName == 'Case') {
            return new RuleConfig('AccountId', 'ContactId');
        }

        List<Zefort_Record_Resolver__mdt> configs = [
            SELECT Account_Path__c, Contact_Path__c
            FROM Zefort_Record_Resolver__mdt
            WHERE Active__c = true AND Object_Api_Name__c = :objectApiName
            ORDER BY DeveloperName ASC
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            return null;
        }

        Zefort_Record_Resolver__mdt config = configs[0];
        return new RuleConfig(config.Account_Path__c, config.Contact_Path__c);
    }

    private static String inferObjectApiName(String recordId) {
        try {
            Id sourceRecordId = (Id) recordId;
            return sourceRecordId.getSObjectType().getDescribe().getName();
        } catch (Exception e) {
            System.debug('Could not infer object API name: ' + e.getMessage());
            return null;
        }
    }

    private static SObject loadSourceRecord(
        String objectApiName,
        String recordId,
        Set<String> fieldPaths
    ) {
        if (!isSafeObjectName(objectApiName)) {
            throw new AuraHandledException('Unsafe object API name for resolver query.');
        }

        List<String> selectedFields = new List<String>{'Id'};
        for (String fieldPath : fieldPaths) {
            if (String.isBlank(fieldPath)) {
                continue;
            }
            if (!isSafeFieldPath(fieldPath)) {
                throw new AuraHandledException('Unsafe field path in resolver query: ' + fieldPath);
            }
            if (!selectedFields.contains(fieldPath)) {
                selectedFields.add(fieldPath);
            }
        }

        String query =
            'SELECT ' +
            String.join(selectedFields, ',') +
            ' FROM ' +
            objectApiName +
            ' WHERE Id = \'' +
            String.escapeSingleQuotes(recordId) +
            '\' WITH SECURITY_ENFORCED LIMIT 1';
        List<SObject> rows = Database.query(query);
        if (rows.isEmpty()) {
            throw new AuraHandledException('Source record not found for resolver.');
        }
        return rows[0];
    }

    private static Object valueForPath(SObject sourceRecord, String path) {
        if (sourceRecord == null || String.isBlank(path)) {
            return null;
        }
        if (!path.contains('.')) {
            return sourceRecord.get(path);
        }

        List<String> parts = path.split('\\.');
        SObject current = sourceRecord;
        for (Integer i = 0; i < parts.size(); i++) {
            String part = parts[i];
            if (current == null) {
                return null;
            }

            Boolean isLast = i == (parts.size() - 1);
            if (isLast) {
                return current.get(part);
            }
            current = current.getSObject(part);
        }

        return null;
    }

    private static Boolean isSafeObjectName(String objectApiName) {
        return Pattern.matches('^[A-Za-z0-9_]+$', objectApiName);
    }

    private static Boolean isSafeFieldPath(String path) {
        return Pattern.matches('^[A-Za-z0-9_\\.]+$', path);
    }
}