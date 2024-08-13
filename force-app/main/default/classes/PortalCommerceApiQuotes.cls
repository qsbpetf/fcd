/**
 * Created by peterfriberg on 2024-08-13.
 */

public with sharing class PortalCommerceApiQuotes
{
    static private PortalCommerceApiQuotes instance;
    static private PortalCommerceApiClient client;

    static public PortalCommerceApiQuotes getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiQuotes();
            client = PortalCommerceApiClient.getInstance();
        }
        return instance;
    }

    public QuoteList getQuotes(Integer pageSize, String nextId, String transactionAccountId) {
        HttpResponse response = client.getQuotes(pageSize, nextId, transactionAccountId);
        QuoteList products = (QuoteList) JSON.deserialize(
            response.getBody()
                .replaceAll('"number"', '"quoteNumber"')
                .replaceAll('"currency"', '"isoCurrency"'),
            QuoteList.class);
        return products;
    }

    @AuraEnabled
    public static QuoteList getQuotesStatic(Integer pageSize, String nextId, String transactionAccountId) {
        PortalCommerceApiQuotes instance = PortalCommerceApiQuotes.getInstance();
        return instance.getQuotes(pageSize, nextId, transactionAccountId);
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class QuoteList {
        @AuraEnabled public List<QuoteInfo> data;
        @AuraEnabled public String nextId;
    }

    public class QuoteInfo {
        @AuraEnabled public String id;
        @AuraEnabled public String contractType;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public String reasonCode;
        @AuraEnabled public String status;
        @AuraEnabled public Long createdAt;
        @AuraEnabled public Long expiresAt;
        @AuraEnabled public List<QuoteItem> lineItems;
        @AuraEnabled public BillItem upcomingBills;
    }

    public class QuoteItem {
        @AuraEnabled public String lineItemId;
        @AuraEnabled public String lineItemType;
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
        @AuraEnabled public String description;
        @AuraEnabled public Long total;
        @AuraEnabled public Long subTotal;
        @AuraEnabled public String isoCurrency;
        @AuraEnabled public PeriodType period;
        @AuraEnabled public Integer quantity;
    }

    public class PeriodType {
        @AuraEnabled public Long startsAt;
        @AuraEnabled public Long endsAt;
    }
}