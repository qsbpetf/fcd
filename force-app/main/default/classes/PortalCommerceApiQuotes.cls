/**
 * Created by peterfriberg on 2024-08-13.
 */

public with sharing class PortalCommerceApiQuotes
{
    @TestVisible static private PortalCommerceApiQuotes instance;
    @TestVisible static private PortalCommerceApiClient client;

    static public PortalCommerceApiQuotes getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiQuotes();
            client = PortalCommerceApiClient.getInstance();
        }
        return instance;
    }

    public static void setApiClient(PortalCommerceApiClient apiClient) {
        client = apiClient;
    }

    public QuoteList getQuotes(String office, Integer pageSize, String nextId) {
        String invoiceGroupId = null;
        HttpResponse response = client.getQuotes(office, invoiceGroupId, pageSize, nextId);
        if (response.getStatusCode() != 200) {
            QuoteList quotes = new QuoteList();
            quotes.error = response.getBody();
            quotes.missingAccountId = true;
            return quotes;
        }
        QuoteList quotes = (QuoteList) JSON.deserialize(
            response.getBody()
                .replaceAll('"number"', '"quoteNumber"')
                .replaceAll('"currency"', '"isoCurrency"'),
            QuoteList.class);
        return quotes;
    }

    @AuraEnabled
    public static QuoteList getQuotesStatic(String office, Integer pageSize, String nextId) {
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        return instance.getQuotes(office, pageSize, nextId);
    }

    public QuoteInfo getQuote(String office, String quoteId) {
        HttpResponse response = client.getQuote(office, quoteId);
        if (response.getStatusCode() != 200) {
            QuoteInfo theQuote = new QuoteInfo();
            theQuote.error = response.getBody();
            theQuote.missingAccountId = true;
            return theQuote;
        }
        QuoteInfo theQuote = (QuoteInfo) JSON.deserialize(
            response.getBody()
                .replaceAll('"number"', '"quoteNumber"')
                .replaceAll('"currency"', '"isoCurrency"'),
            QuoteInfo.class);
        System.debug('QUOTE = ' + response.getBody());
        return theQuote;
    }

    @AuraEnabled
    public static QuoteInfo getQuoteStatic(String office, String quoteId) {
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        return instance.getQuote(office, quoteId);
    }

    public String getQuotePdf(String office, String quoteId) {
        HttpResponse response = client.getQuotePdf(office, quoteId);
        if (response.getStatusCode() != 200) {
            return response.getBody();
        }
        String responseBody = EncodingUtil.base64Encode(response.getBodyAsBlob());
        return responseBody;
    }

    @AuraEnabled
    public static String getQuotePdfStatic(String office, String quoteId) {
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        return instance.getQuotePdf(office, quoteId);
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class QuoteList {
        @AuraEnabled public List<QuoteInfo> data;
        @AuraEnabled public String nextId;
        @AuraEnabled public String error;
        @AuraEnabled public Boolean missingAccountId;

        public QuoteList() {
            data = new List<QuoteInfo>();
            error = null;
            missingAccountId = false;
        }
    }

    public class QuoteInfo {
        @AuraEnabled public String id;
        @AuraEnabled public Integer version;
        @AuraEnabled public String contractType;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String reasonCode;
        @AuraEnabled public String status;
        @AuraEnabled public Long createdAt;
        @AuraEnabled public Long expiresAt;
        @AuraEnabled public List<QuoteItem> lineItems;
        @AuraEnabled public BillItem upcomingBills;
        @AuraEnabled public String error;
        @AuraEnabled public Boolean missingAccountId;
        @AuraEnabled public String office;
    }

    public class QuoteItem {
        @AuraEnabled public String lineItemId;
        @AuraEnabled public String entitlementId;
        @AuraEnabled public String lineItemType;
        @AuraEnabled public String orderItemId;
        @AuraEnabled public TimeInfo startsAt;
        @AuraEnabled public TimeInfo endsAt;

    }

    public class TimeInfo {
        @AuraEnabled public Long timestamp;
        @AuraEnabled public String type;
        @AuraEnabled public DurationType duration;
    }

    public class DurationType {
        @AuraEnabled public String interval;
        @AuraEnabled public Integer intervalCount;
    }

    public class BillItem {
        @AuraEnabled public Long total;
        @AuraEnabled public Long subTotal;
        @AuraEnabled public List<BillLineItem> lines;
    }

    public class BillLineItem {
        @AuraEnabled public String id;
        @AuraEnabled public String quoteLineId;
        @AuraEnabled public String description;
        @AuraEnabled public Long total;
        @AuraEnabled public Long subTotal;
        @AuraEnabled public Long amountExcludingTax;
        @AuraEnabled public Double amountExcludingTaxDecimal;
        @AuraEnabled public Long tax;
        @AuraEnabled public String isoCurrency;
        @AuraEnabled public PeriodType period;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public String entName;
        @AuraEnabled public String entSlug;
        @AuraEnabled public String entAri;
        @AuraEnabled public List<AdjustmentType> adjustments;
        @AuraEnabled public List<MarginType> margins;
        @AuraEnabled public Long discount;
        @AuraEnabled public Double discountAmount;
        @AuraEnabled public Long adjustment;
        @AuraEnabled public Double adjustmentAmount;
        @AuraEnabled public String salesType;
        @AuraEnabled public String offeringId;
        @AuraEnabled public String offeringKey;
        @AuraEnabled public String offeringName;
        @AuraEnabled public String productName;
        @AuraEnabled public String sfProductName;
    }

    public class PeriodType {
        @AuraEnabled public Long startsAt;
        @AuraEnabled public Long endsAt;
    }

    public class MarginType {
        @AuraEnabled public String type;
        @AuraEnabled public String reasonCode;
        @AuraEnabled public Long amount;
        @AuraEnabled public Decimal percent;
    }

    public class AdjustmentType {
        @AuraEnabled public String type;
        @AuraEnabled public String reasonCode;
        @AuraEnabled public Long amount;
        @AuraEnabled public Decimal percent;
    }
}