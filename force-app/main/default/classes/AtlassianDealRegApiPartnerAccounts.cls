/**
 * Service layer for Atlassian Deal Registration API partner accounts.
 * Provides typed access to the list of partner accounts the caller can act on.
 */
public with sharing class AtlassianDealRegApiPartnerAccounts {

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
     *
     * @return PartnerAccountsResponse with partnerAccounts list
     */
    public PartnerAccountsResponse getPartnerAccounts() {
        HttpResponse response = client.listPartnerAccounts();
        PartnerAccountsResponse result = (PartnerAccountsResponse) JSON.deserialize(response.getBody(), PartnerAccountsResponse.class);
        if (result.partnerAccounts == null) {
            result.partnerAccounts = new List<PartnerAccount>();
        }
        return result;
    }

    /**
     * Static wrapper for LWC/Flow use.
     *
     * @return PartnerAccountsResponse with partnerAccounts list
     */
    @AuraEnabled(Cacheable=false)
    public static PartnerAccountsResponse getPartnerAccountsStatic() {
        AtlassianDealRegApiPartnerAccounts instance = AtlassianDealRegApiPartnerAccounts.getInstance();
        return instance.getPartnerAccounts();
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
