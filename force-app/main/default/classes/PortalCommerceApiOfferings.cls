/**
 * Created by peterfriberg on 2024-12-01.
 */

public with sharing class PortalCommerceApiOfferings {

    @TestVisible static private PortalCommerceApiOfferings instance;
    @TestVisible static private PortalCommerceApiClient client;

    static public PortalCommerceApiOfferings getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiOfferings();
            client = PortalCommerceApiClient.getInstance();
        }
        return instance;
    }

    public static void setApiClient(PortalCommerceApiClient apiClient) {
        client = apiClient;
    }

    public OfferingList getOfferings(String office, String productId, Integer pageSize, String nextId) {
        HttpResponse response = client.getOfferings(office, productId, pageSize, nextId);
        OfferingList products = (OfferingList) JSON.deserialize(response.getBody(), OfferingList.class);
        if (products.values == null) {
            products.values = new List<PortalCommerceApiOfferings.OfferingInfo>();
        }
        return products;
    }

    @AuraEnabled
    public static OfferingList getOfferingsStatic(String office, String productId, Integer pageSize, String nextId) {
        PortalCommerceApiClient client = PortalCommerceApiClient.getInstance();
        PortalCommerceApiOfferings instance = PortalCommerceApiOfferings.getInstance();
        return instance.getOfferings(office, productId, pageSize, nextId);
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class OfferingList {
        @AuraEnabled public List<OfferingInfo> values;
        @AuraEnabled public String nextId;
    }

    public class OfferingInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String ari;
        @AuraEnabled public Long updatedAt;
        @AuraEnabled public String hostingType;
        @AuraEnabled public Integer level;
        @AuraEnabled public String productId;
        @AuraEnabled public String pricingType;
        @AuraEnabled public String status;
        @AuraEnabled public Integer version;
        @AuraEnabled public List<String> supportedBillingSystems;
    }
}