public with sharing class ZefortRegion {
    @AuraEnabled(cacheable=true)
    public static String getRegion() {
        ZefortSettings__c settings = ZefortSettings__c.getInstance();
        
        // Handle installations where the field doesn't exist yet
        try {
            // Get the region value
            return settings.get('Region__c') != null ? (String)settings.get('Region__c') : 'sandbox';
        } catch (Exception e) {
            // If field doesn't exist yet, return default
            return 'sandbox';
        }
    }
    
    @AuraEnabled
    public static void setRegion(String region, String dedicatedUrl) {
        ensureRegionWritable();
        String normalizedRegion = normalizeRegion(region);

        if (normalizedRegion == 'dedicated' && String.isBlank(dedicatedUrl)) {
            throw new AuraHandledException('Custom domain is required when region is dedicated.');
        }

        ZefortSettings__c settings = ZefortSettings__c.getInstance();
        settings.Region__c = normalizedRegion;
        settings.CustomDomain__c = normalizedRegion == 'dedicated'
            ? dedicatedUrl.trim()
            : null;

        upsert settings;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRegionOptions() {
        return new Map<String, String>{
            'sandbox' => 'https://sandbox.zefort.com',
            'eu' => 'https://my.zefort.com',
            'us' => 'https://us.zefort.com',
            'dedicated' => 'Custom Domain'
        };
    }

    private static String normalizeRegion(String region) {
        if (String.isBlank(region)) {
            return 'sandbox';
        }

        String normalized = region.trim().toLowerCase();
        if (
            normalized == 'sandbox' ||
            normalized == 'eu' ||
            normalized == 'us' ||
            normalized == 'dedicated'
        ) {
            return normalized;
        }
        throw new AuraHandledException('Unsupported region value.');
    }

    private static void ensureRegionWritable() {
        Schema.DescribeSObjectResult objectDescribe = ZefortSettings__c.SObjectType.getDescribe();
        Schema.DescribeFieldResult regionDescribe = ZefortSettings__c.Region__c.getDescribe();
        Schema.DescribeFieldResult customDomainDescribe = ZefortSettings__c.CustomDomain__c.getDescribe();
        if (
            !objectDescribe.isAccessible() ||
            !objectDescribe.isUpdateable() ||
            !regionDescribe.isAccessible() ||
            !regionDescribe.isUpdateable() ||
            !customDomainDescribe.isAccessible() ||
            !customDomainDescribe.isUpdateable()
        ) {
            throw new AuraHandledException('Insufficient permissions to update Zefort region settings.');
        }
    }
}