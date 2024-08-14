/**
 * Created by peterfriberg on 2024-08-13.
 */

public with sharing class PortalCommerceApiInvoices
{
    static private PortalCommerceApiInvoices instance;
    static private PortalCommerceApiClient client;

    static public PortalCommerceApiInvoices getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiInvoices();
            client = PortalCommerceApiClient.getInstance();
        }
        return instance;
    }

    public InvoiceList getInvoices(Integer pageSize, String nextId, String transactionAccountId) {
        HttpResponse response = client.getInvoices(pageSize, nextId, transactionAccountId);
        if (response.getStatusCode() != 200) {
            InvoiceList invoices = new InvoiceList();
            invoices.error = response.getBody();
            invoices.missingAccountId = true;
            return invoices;
        }
        InvoiceList products = (InvoiceList) JSON.deserialize(
            response.getBody()
                .replaceAll('"number"', '"invoiceNumber"')
                .replaceAll('"currency"', '"isoCurrency"'),
            InvoiceList.class);
        return products;
    }

    @AuraEnabled
    public static InvoiceList getInvoicesStatic(Integer pageSize, String nextId, String transactionAccountId) {
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        return instance.getInvoices(pageSize, nextId, transactionAccountId);
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class InvoiceList {
        @AuraEnabled public List<InvoiceInfo> data;
        @AuraEnabled public String nextId;
        @AuraEnabled public String error;
        @AuraEnabled public Boolean missingAccountId;

        public InvoiceList() {
            data = new List<InvoiceInfo>();
            error = null;
            missingAccountId = false;
        }
    }

    public class InvoiceInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String status;
        @AuraEnabled public String invoiceNumber;
        @AuraEnabled public String additionalNotes;
        @AuraEnabled public String isoCurrency;
        @AuraEnabled public Double total;
        @AuraEnabled public Double subTotal;
        @AuraEnabled public Long createdAt;
        @AuraEnabled public Long dueAt;
        @AuraEnabled public List<InvoiceItem> items;
    }

    public class InvoiceItem {
        @AuraEnabled public String id;
        @AuraEnabled public String description;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public Double unitAmount;
        @AuraEnabled public Double total;
        @AuraEnabled public Double subtotal;
        @AuraEnabled public PeriodInfo period;
    }

    public class PeriodInfo {
        @AuraEnabled public Long startAt;
        @AuraEnabled public Long endAt;
    }

}