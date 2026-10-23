public without sharing class ZefortAuthService {
    private static final String ORG_AUTH_RECORD_NAME = 'Org Default';

    @AuraEnabled
    public static void saveUserApiKey(String apiKey) {
        ensureAuthWritable();
        Zefort_Auth__c authRecord = getOrCreateOrgAuthRecord();
        authRecord.API_Key__c = apiKey;
        upsert authRecord;
    }
    
    @AuraEnabled(cacheable=true)
    public static Boolean hasApiKey() {
        ensureAuthReadable();
        return !String.isBlank(resolveCurrentApiKey());
    }
    
    @AuraEnabled(cacheable=true)
    public static String getApiKeyMask() {
        ensureAuthReadable();
        String apiKey = resolveCurrentApiKey();
        if (String.isBlank(apiKey)) {
            return null;
        }
        Integer keyLength = apiKey.length();
        if (keyLength <= 4) {
            return '****';
        }
        return '...' + apiKey.substring(keyLength - 4, keyLength);
    }

    public static String getUserApiKey() {
        ensureAuthReadable();
        String apiKey = resolveCurrentApiKey();
        if (String.isBlank(apiKey)) {
            throw new AuraHandledException('No API key configured');
        }
        return apiKey;
    }

    private static Zefort_Auth__c getOrgAuthRecord() {
        List<Zefort_Auth__c> rows = [
            SELECT Id, Name, API_Key__c
            FROM Zefort_Auth__c
            WHERE User__c = null
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static Zefort_Auth__c getOrCreateOrgAuthRecord() {
        Zefort_Auth__c authRecord = getOrgAuthRecord();
        if (authRecord == null) {
            authRecord = new Zefort_Auth__c();
            authRecord.Name = ORG_AUTH_RECORD_NAME;
        }
        return authRecord;
    }

    private static String resolveCurrentApiKey() {
        Zefort_Auth__c authRecord = getOrgAuthRecord();
        if (authRecord != null && !String.isBlank(authRecord.API_Key__c)) {
            return authRecord.API_Key__c;
        }
        return null;
    }

    private static void ensureAuthReadable() {
        Schema.DescribeSObjectResult objectDescribe = Zefort_Auth__c.SObjectType.getDescribe();
        Schema.DescribeFieldResult fieldDescribe = Zefort_Auth__c.API_Key__c.getDescribe();
        if (!objectDescribe.isAccessible() || !fieldDescribe.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to read Zefort API settings.');
        }
    }

    private static void ensureAuthWritable() {
        Schema.DescribeSObjectResult objectDescribe = Zefort_Auth__c.SObjectType.getDescribe();
        Schema.DescribeFieldResult fieldDescribe = Zefort_Auth__c.API_Key__c.getDescribe();
        Boolean objectWritable = objectDescribe.isCreateable() || objectDescribe.isUpdateable();
        if (!objectWritable || !fieldDescribe.isUpdateable()) {
            throw new AuraHandledException('Insufficient permissions to update Zefort API settings.');
        }
    }
}