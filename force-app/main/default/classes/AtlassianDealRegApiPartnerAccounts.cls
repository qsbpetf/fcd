/**
 * Service layer for Atlassian Deal Registration API partner accounts.
 * Provides typed access to the list of partner accounts the caller can act on.
 * Uses ApiResponseCache__c for a 15-minute TTL cache of the partner accounts list.
 */
public with sharing class AtlassianDealRegApiPartnerAccounts {

    private static final String CACHE_KEY_PARTNER_ACCOUNTS = 'PartnerAccounts';
    @TestVisible static Integer ttlMinutes = 15;

    @TestVisible static private AtlassianDealRegApiPartnerAccounts instance;
    @TestVisible static private AtlassianDealRegApiClient client;

    static public AtlassianDealRegApiPartnerAccounts getInstance() {
        if (instance == null) {
            instance = new AtlassianDealRegApiPartnerAccounts();
            client = AtlassianDealRegApiClient.getInstance();
        }
        return instance;
    }

    public static void setApiClient(AtlassianDealRegApiClient apiClient) {
        client = apiClient;
    }

    /**
     * Returns the list of partner accounts accessible to the authenticated caller.
     * Uses ApiResponseCache__c with 15-minute TTL; returns cached JSON if valid, else calls API and upserts cache on 200.
     *
     * @param forceRefresh When true, bypasses cache read and always calls the API (avoids DML-before-callout restriction).
     * @return PartnerAccountsResponse with partnerAccounts list
     */
    public PartnerAccountsResponse getPartnerAccounts(Boolean forceRefresh) {
        if (forceRefresh != true) {
            List<ApiResponseCache__c> cached = new List<ApiResponseCache__c>([
                SELECT Id, ResponseJson__c, LastModifiedDate
                FROM ApiResponseCache__c
                WHERE CacheKey__c = :CACHE_KEY_PARTNER_ACCOUNTS
                LIMIT 1
            ]);
            if (!cached.isEmpty()) {
                ApiResponseCache__c rec = cached[0];
                if (rec.ResponseJson__c != null && isCacheValid(rec.LastModifiedDate)) {
                    try {
                        PartnerAccountsResponse result = (PartnerAccountsResponse) JSON.deserialize(rec.ResponseJson__c, PartnerAccountsResponse.class);
                        if (result.partnerAccounts == null) {
                            result.partnerAccounts = new List<PartnerAccount>();
                        }
                        return result;
                    } catch (JSONException e) {
                        // Corrupt cache; fall through to API call
                    }
                }
            }
        }

        HttpResponse response = client.listPartnerAccounts();
        String body = response.getBody();
        if (response.getStatusCode() == 200 && String.isNotBlank(body)) {
            upsert new ApiResponseCache__c(
                CacheKey__c = CACHE_KEY_PARTNER_ACCOUNTS,
                Name = CACHE_KEY_PARTNER_ACCOUNTS,
                ResponseJson__c = body
            ) CacheKey__c;
        }

        PartnerAccountsResponse result;
        try {
            result = (PartnerAccountsResponse) JSON.deserialize(body, PartnerAccountsResponse.class);
        } catch (JSONException e) {
            result = new PartnerAccountsResponse();
        }
        if (result.partnerAccounts == null) {
            result.partnerAccounts = new List<PartnerAccount>();
        }
        return result;
    }

    private Boolean isCacheValid(Datetime lastModified) {
        if (lastModified == null || ttlMinutes == null || ttlMinutes <= 0) {
            return false;
        }
        return Datetime.now().addMinutes(-ttlMinutes) <= lastModified;
    }

    /**
     * Static wrapper for LWC/Flow use.
     *
     * @param forceRefresh When true, bypasses cache and calls the API to refresh the cache.
     * @return PartnerAccountsResponse with partnerAccounts list
     */
    @AuraEnabled(Cacheable=false)
    public static PartnerAccountsResponse getPartnerAccountsStatic(Boolean forceRefresh) {
        AtlassianDealRegApiPartnerAccounts instance = AtlassianDealRegApiPartnerAccounts.getInstance();
        return instance.getPartnerAccounts(forceRefresh == true);
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class PartnerAccountsResponse {
        @AuraEnabled public List<PartnerAccount> partnerAccounts;
    }

    public class PartnerAccount {
        /** partnerId from API; use this value for X-Partner-Account-Id header on other endpoints */
        @AuraEnabled public String partnerId;
        @AuraEnabled public String accountName;
        @AuraEnabled public List<String> roles;
        @AuraEnabled public Boolean isPrimary;
    }
}
