/**
 * Created by peterfriberg on 2024-08-22.
 */

public with sharing class PortalCommerceApiInvoiceGroups {

    static private PortalCommerceApiInvoiceGroups instance;
    static private PortalCommerceApiClient client;

    static public PortalCommerceApiInvoiceGroups getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiInvoiceGroups();
            client = PortalCommerceApiClient.getInstance();
        }
        return instance;
    }

    public InvoiceGroupList getInvoiceGroups(String office, Integer pageSize, String nextId) {
        HttpResponse response = client.getInvoiceGroups(office, pageSize, nextId);
        if (response.getStatusCode() != 200) {
            InvoiceGroupList invoiceGroups = new InvoiceGroupList();
            invoiceGroups.error = response.getBody();
            invoiceGroups.missingAccountId = true;
            return invoiceGroups;
        }
        InvoiceGroupList invoiceGroups = (InvoiceGroupList) JSON.deserialize(
            response.getBody()
                .replaceAll('"currency"', '"isoCurrency"'),
            InvoiceGroupList.class);
        return invoiceGroups;
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class InvoiceGroupList {
        @AuraEnabled public List<InvoiceGroupInfo> data;
        @AuraEnabled public String nextId;
        @AuraEnabled public String error;
        @AuraEnabled public Boolean missingAccountId;

        public InvoiceGroupList() {
            data = new List<InvoiceGroupInfo>();
            error = null;
            missingAccountId = false;
        }
    }

    public class InvoiceGroupInfo {
        @AuraEnabled public String id;
        @AuraEnabled public Integer version;
        @AuraEnabled public String name;
        @AuraEnabled public String isoCurrency;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Long createdAt;
        @AuraEnabled public ShipToPartyInfo shipToParty;
    }

    public class ShipToPartyInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String taxId;
    }
}