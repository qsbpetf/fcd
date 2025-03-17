/**
 * Created by peterfriberg on 2024-08-13.
 */

public with sharing class PortalCommerceApiInvoices
{
    @TestVisible static private PortalCommerceApiInvoices instance;
    @TestVisible static private PortalCommerceApiClient client;

    static public PortalCommerceApiInvoices getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiInvoices();
            client = PortalCommerceApiClient.getInstance();
        }
        return instance;
    }

    public static void setApiClient(PortalCommerceApiClient apiClient) {
        client = apiClient;
    }

    public InvoiceList getInvoices(String office, String invoiceGroupId, Integer pageSize, String nextId) {
        HttpResponse response = client.getInvoices(office, invoiceGroupId, pageSize, nextId);
        if (response.getStatusCode() != 200) {
            InvoiceList invoices = new InvoiceList();
            invoices.error = response.getBody();
            invoices.missingAccountId = true;
            return invoices;
        }
        InvoiceList products = (InvoiceList) JSON.deserialize(
            response.getBody()
                .replaceAll('"number"', '"invoiceNumber"')
                .replaceAll('"currency"', '"isoCurrency"')
                .replaceAll('"Entitlement Display Info"', '"EntitlementDisplayInfos"'),
            InvoiceList.class);
        return products;
    }

    @AuraEnabled
    public static InvoiceList getInvoicesStatic(String office, String invoiceGroupId, Integer pageSize, String nextId) {
        PortalCommerceApiInvoices instance = PortalCommerceApiInvoices.getInstance();
        return instance.getInvoices(office, invoiceGroupId, pageSize, nextId);
    }

    public InvoiceInfo getInvoice(String office, String invoiceId) {
        HttpResponse response = client.getInvoice(office, invoiceId);
        if (response.getStatusCode() != 200) {
            return null;
        }
        System.debug('JSON = ' + response.getBody());
        InvoiceInfo invoice = (InvoiceInfo) JSON.deserialize(
            response.getBody()
                .replaceAll('"number"', '"invoiceNumber"')
                .replaceAll('"currency"', '"isoCurrency"'),
            InvoiceInfo.class);
        return invoice;
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class InvoiceList {
        @AuraEnabled public List<InvoiceInfo> data;
        @AuraEnabled public List<EntitlementDetail> EntitlementDetails;
        @AuraEnabled public List<EntitlementDisplayInfo> EntitlementDisplayInfos;
        @AuraEnabled public List<OrderDetailsType> orderDetails;
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
        @AuraEnabled public Long paidAt;
        @AuraEnabled public List<InvoiceItem> items;
        @AuraEnabled public String office;
    }

    public class InvoiceItem {
        @AuraEnabled public String id;
        @AuraEnabled public String description;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public Double unitAmount;
        @AuraEnabled public Double total;
        @AuraEnabled public Double subTotal;
        @AuraEnabled public Long amountExcludingTax;
        @AuraEnabled public Double amountExcludingTaxDecimal;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public PeriodInfo period;
        @AuraEnabled public String entitlementId;
        @AuraEnabled public String entitlementNumber;
        @AuraEnabled public PlanObjectInfo planObj;
        @AuraEnabled public List<AdjustmentType> adjustments;
        @AuraEnabled public List<MarginType> margins;
        @AuraEnabled public Double discountAmount;
        @AuraEnabled public Long adjustment;
        @AuraEnabled public Double adjustmentAmount;
        @AuraEnabled public String salesType;
        @AuraEnabled public String orderId;
        @AuraEnabled public String orderItemId;
        @AuraEnabled public String offeringKey;
    }

    public class OrderDetailsType {
        @AuraEnabled public List<OrderLineType> items;
    }

    public class OrderLineType {
        @AuraEnabled public ProcessingInfoType processingInfo;
    }

    public class ProcessingInfoType {
        @AuraEnabled public String saleTransitionType;
    }

    public class PlanObjectInfo {
        @AuraEnabled public String type;
        @AuraEnabled public String hostingType;
        @AuraEnabled public CycleType cycle;
    }

    public class CycleType {
        @AuraEnabled public String interval;
    }

    public class PeriodInfo {
        @AuraEnabled public Long startAt;
        @AuraEnabled public Long endAt;
    }

    public class MarginType {
        @AuraEnabled public String type;
        @AuraEnabled public String reasonCode;
        @AuraEnabled public Double amount;
        @AuraEnabled public Integer percent;
    }

    public class AdjustmentType {
        @AuraEnabled public String type;
        @AuraEnabled public String reasonCode;
        @AuraEnabled public Double amount;
        @AuraEnabled public Integer percent;
    }

    public class EntitlementDetail {
        @AuraEnabled public String entitlementId;
        @AuraEnabled public String status;
        @AuraEnabled public String slug;
    }

    public class EntitlementDisplayInfo {
        @AuraEnabled public String entitlementId;
        @AuraEnabled public ProvisionedResourceInfo provisionedResource;
    }

    public class ProvisionedResourceInfo {
        @AuraEnabled public String ari;
        @AuraEnabled public String name;
    }
}