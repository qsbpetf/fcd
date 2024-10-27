/**
 * Created by peterfriberg on 2024-09-10.
 */

public with sharing class PortalCommerceApiEntitlements {

    @TestVisible static private PortalCommerceApiEntitlements instance;
    @TestVisible static private PortalCommerceApiClient client;

    static public PortalCommerceApiEntitlements getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiEntitlements();
            client = PortalCommerceApiClient.getInstance();
        }
        return instance;
    }

    public static void setApiClient(PortalCommerceApiClient apiClient) {
        client = apiClient;
    }

    public EntitlementDisplayInfo getEntitlementDisplayInfo(String office, String entitlementId) {
        HttpResponse response = client.getEntitlementDisplayInfo(office, entitlementId);
        if (response.getStatusCode() != 200) {
            EntitlementDisplayInfo entitlementDisplayInfo = new EntitlementDisplayInfo();
            entitlementDisplayInfo.error = response.getBody();
            entitlementDisplayInfo.missingAccountId = true;
            return entitlementDisplayInfo;
        }
        EntitlementDisplayInfo entitlementDisplayInfo = (EntitlementDisplayInfo) JSON.deserialize(
            response.getBody(),
            EntitlementDisplayInfo.class);
        entitlementDisplayInfo.error = null;
        entitlementDisplayInfo.missingAccountId = false;
        return entitlementDisplayInfo;
    }

    public static EntitlementDisplayInfo getEntitlementDisplayInfoStatic(String office, String entitlementId) {
        PortalCommerceApiEntitlements instance = PortalCommerceApiEntitlements.getInstance();
        return instance.getEntitlementDisplayInfo(office, entitlementId);
    }

    public EntitlementDetails getEntitlementDetails(String office, String entitlementId) {
        HttpResponse response = client.getEntitlementDetails(office, entitlementId);
        if (response.getStatusCode() != 200) {
            EntitlementDetails entitlementDetails = new EntitlementDetails();
            entitlementDetails.error = response.getBody();
            entitlementDetails.missingAccountId = true;
            return entitlementDetails;
        }
        EntitlementDetails entitlementDetails = (EntitlementDetails) JSON.deserialize(
            response.getBody(),
            EntitlementDetails.class);
        entitlementDetails.error = null;
        entitlementDetails.missingAccountId = false;
        return entitlementDetails;
    }

    public static EntitlementDetails getEntitlementDetailsStatic(String office, String entitlementId) {
        PortalCommerceApiEntitlements instance = PortalCommerceApiEntitlements.getInstance();
        return instance.getEntitlementDetails(office, entitlementId);
    }

    public EntitlementPartnerInfo getEntitlementPartnerInfo(String office, String entitlementId) {
        HttpResponse response = client.getEntitlementPartnerInfo(office, entitlementId);
        if (response.getStatusCode() != 200) {
            EntitlementPartnerInfo entitlementPartnerInfo = new EntitlementPartnerInfo();
            entitlementPartnerInfo.error = response.getBody();
            entitlementPartnerInfo.missingAccountId = true;
            return entitlementPartnerInfo;
        }
        EntitlementPartnerInfo entitlementPartnerInfo = (EntitlementPartnerInfo) JSON.deserialize(
            response.getBody().replaceAll('"id"', '"subscriptionId"'),
            EntitlementPartnerInfo.class);
        entitlementPartnerInfo.error = null;
        entitlementPartnerInfo.missingAccountId = false;
        return entitlementPartnerInfo;
    }

    public static EntitlementPartnerInfo getEntitlementPartnerInfoStatic(String office, String entitlementId) {
        PortalCommerceApiEntitlements instance = PortalCommerceApiEntitlements.getInstance();
        return instance.getEntitlementPartnerInfo(office, entitlementId);
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class EntitlementDisplayInfo {
        @AuraEnabled public String entitlementId;
        @AuraEnabled public ProvisionedResourceInfo provisionedResource;
        @AuraEnabled public String error;
        @AuraEnabled public Boolean missingAccountId;
    }

    public class ProvisionedResourceInfo {
        @AuraEnabled public String name;
        @AuraEnabled public String ari;
    }

    public class EntitlementDetails {
        @AuraEnabled public String entitlementId;
        @AuraEnabled public String status;
        @AuraEnabled public String slug;
        @AuraEnabled public String error;
        @AuraEnabled public Boolean missingAccountId;
    }

    public class EntitlementPartnerInfo {
        @AuraEnabled public String entitlementId;
        @AuraEnabled public String status;
        @AuraEnabled public String slug;
        @AuraEnabled public SubscriptionInfo subscription;
        @AuraEnabled public ProvisionedResourceInfo provisionedResource;
        @AuraEnabled public String error;
        @AuraEnabled public Boolean missingAccountId;
    }

    public class SubscriptionInfo {
        @AuraEnabled public String subscriptionId;
        @AuraEnabled public String status;
    }
}