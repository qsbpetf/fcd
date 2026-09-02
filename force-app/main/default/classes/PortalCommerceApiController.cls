/**
 * Created by peterfriberg on 2024-08-13.
 */

public with sharing class PortalCommerceApiController {

    @TestVisible static private PortalCommerceApiQuotes apiQuotes = PortalCommerceApiQuotes.getInstance();
    @TestVisible static private PortalCommerceApiEntitlements apiEntitlements = PortalCommerceApiEntitlements.getInstance();
    @TestVisible static private PortalCommerceApiInvoices apiInvoices = PortalCommerceApiInvoices.getInstance();
    @TestVisible static private PortalCommerceApiOrders apiOrders = PortalCommerceApiOrders.getInstance();
    @TestVisible static private Integer INVOICE_PAGE_SIZE = 4;
    @TestVisible static private Integer INVOICE_VIEWER_PAGE_SIZE = 1;
    @TestVisible static private Integer INVOICE_VIEWER_MAX_LINE_ITEMS = 50;

    public static void setApiQuotes(PortalCommerceApiQuotes api) {
        apiQuotes = api;
    }

    public static void setApiEntitlements(PortalCommerceApiEntitlements api) {
        apiEntitlements = api;
    }

    public static void setApiInvoices(PortalCommerceApiInvoices api) {
        apiInvoices = api;
    }

    public static void setApiOrders(PortalCommerceApiOrders api) {
        apiOrders = api;
    }

    @AuraEnabled
    static public PortalCommerceApiQuotes.QuoteList getQuotes(String opportunityId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiQuotes.QuoteList quotes = apiQuotes.getQuotes(opp.Account.CV_Subsidiary__c, 25, null);
        return quotes;
    }

    @AuraEnabled
    static public PortalCommerceApiQuotes.QuoteInfo getQuote(String opportunityId, String quoteId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiQuotes.QuoteInfo theQuote = apiQuotes.getQuote(opp.Account.CV_Subsidiary__c, quoteId);
        if (theQuote == null) {
            return null;
        }
        theQuote.office = opp.Account.CV_Subsidiary__c;
        return theQuote;
    }

    @AuraEnabled
    static public List<PortalCommerceApiInvoices.InvoiceList> getInvoices(String accountId) {
        Account acc = [SELECT Id, CV_Subsidiary__c FROM Account WHERE Id = :accountId];
        List<InvoiceGroup__c> invoiceGroups = new List<InvoiceGroup__c>([
            SELECT
                Id,
                Name,
                AtlassianInvoiceGroupId__c
            FROM InvoiceGroup__c
            WHERE Account__c = :accountId
            AND Active__c = TRUE
            ORDER BY CreatedAt__c DESC
        ]);
        List<PortalCommerceApiInvoices.InvoiceList> allInvoices = new List<PortalCommerceApiInvoices.InvoiceList>();
        Integer calloutsLeft = Limits.getLimitCallouts() - Limits.getCallouts();
        System.debug('### IN: Callouts left: ' + calloutsLeft);
        for (InvoiceGroup__c invoiceGroup : invoiceGroups) {
            String nextId = null;
            calloutsLeft = Limits.getLimitCallouts() - Limits.getCallouts();
            if (calloutsLeft <= 2) {
                System.debug('### No callouts left. Skipping invoice group: ' + invoiceGroup.Name + ' (' + invoiceGroup.AtlassianInvoiceGroupId__c + ')');
                break;
            }
            do {
                System.debug('### Fetching invoices for invoice group: ' + invoiceGroup.Name + ' (' + invoiceGroup.AtlassianInvoiceGroupId__c + ')');
                PortalCommerceApiInvoices.InvoiceList invoices = apiInvoices.getInvoices(acc.CV_Subsidiary__c, invoiceGroup.AtlassianInvoiceGroupId__c, INVOICE_VIEWER_PAGE_SIZE, nextId);
                System.debug('### Fetched ' + invoices.data.size() + ' invoices of max ' + INVOICE_VIEWER_PAGE_SIZE + '. nextId = ' + invoices.nextId);
                allInvoices.add(invoices);
                nextId = invoices.nextId;
                calloutsLeft--;
            } while (nextId != null && calloutsLeft > 0);
        }
        System.debug('### OUT: Callouts left: ' + calloutsLeft);
        prepareInvoicesForDisplay(allInvoices, acc.CV_Subsidiary__c);
        return allInvoices;
    }

    @AuraEnabled
    static public InvoicePageResult getInvoicesPage(String accountId, Integer invoiceGroupIndex, String nextId) {
        InvoicePageResult result = new InvoicePageResult();
        Integer groupIndex = invoiceGroupIndex == null ? 0 : invoiceGroupIndex;
        String currentNextId = nextId;

        Account acc = [SELECT Id, CV_Subsidiary__c FROM Account WHERE Id = :accountId];
        List<InvoiceGroup__c> invoiceGroups = new List<InvoiceGroup__c>([
            SELECT Id, Name, AtlassianInvoiceGroupId__c
            FROM InvoiceGroup__c
            WHERE Account__c = :accountId
            AND Active__c = TRUE
            ORDER BY CreatedAt__c DESC
        ]);

        if (invoiceGroups.isEmpty()) {
            result.error = 'No active invoice groups found';
            result.missingAccountId = true;
            return result;
        }

        if (groupIndex >= invoiceGroups.size()) {
            result.invoiceGroupIndex = groupIndex;
            return result;
        }

        Integer pagesFetched = 0;
        Integer maxPagesPerRequest = Math.min(10, Limits.getLimitCallouts() - Limits.getCallouts() - 2);

        while (groupIndex < invoiceGroups.size() && pagesFetched < maxPagesPerRequest) {
            InvoiceGroup__c invoiceGroup = invoiceGroups[groupIndex];
            PortalCommerceApiInvoices.InvoiceList invoices;
            try {
                invoices = apiInvoices.getInvoices(
                    acc.CV_Subsidiary__c,
                    invoiceGroup.AtlassianInvoiceGroupId__c,
                    INVOICE_VIEWER_PAGE_SIZE,
                    currentNextId
                );
            } catch (System.CalloutException ex) {
                invoices = new PortalCommerceApiInvoices.InvoiceList();
                invoices.error = ex.getMessage();
                invoices.missingAccountId = true;
            }

            if (invoices == null || invoices.missingAccountId == true) {
                if (invoices != null && isCalloutSizeLimitError(invoices.error)) {
                    return buildOversizedInvoiceResult(result, currentNextId, acc.CV_Subsidiary__c, groupIndex);
                }
                result.error = invoices == null ? 'No response from invoice API' : invoices.error;
                result.missingAccountId = true;
                result.invoiceGroupIndex = groupIndex;
                return result;
            }

            if (invoices.data == null) {
                invoices.data = new List<PortalCommerceApiInvoices.InvoiceInfo>();
            }

            pagesFetched++;

            if (!invoices.data.isEmpty()) {
                prepareInvoicesForDisplay(new List<PortalCommerceApiInvoices.InvoiceList>{ invoices }, acc.CV_Subsidiary__c);
                trimInvoicesForViewer(invoices.data);
                result.data = invoices.data;
                result.nextId = invoices.nextId;

                if (invoices.nextId != null) {
                    result.hasMore = true;
                    result.invoiceGroupIndex = groupIndex;
                } else if (groupIndex + 1 < invoiceGroups.size()) {
                    result.hasMore = true;
                    result.nextId = null;
                    result.invoiceGroupIndex = groupIndex + 1;
                } else {
                    result.invoiceGroupIndex = groupIndex;
                }
                return result;
            }

            if (invoices.nextId != null) {
                currentNextId = invoices.nextId;
            } else {
                groupIndex++;
                currentNextId = null;
            }
        }

        result.invoiceGroupIndex = groupIndex;
        result.nextId = currentNextId;
        result.hasMore = currentNextId != null || groupIndex < invoiceGroups.size();
        return result;
    }

    @AuraEnabled
    static public List<PortalCommerceApiInvoices.InvoiceList> getPaidInvoices(String accountId, Integer lastNdays) {
        Account acc = [SELECT Id, CV_Subsidiary__c FROM Account WHERE Id = :accountId];
        List<InvoiceGroup__c> invoiceGroups = new List<InvoiceGroup__c>([
            SELECT
                Id,
                Name,
                AtlassianInvoiceGroupId__c
            FROM InvoiceGroup__c
            WHERE Account__c = :accountId
            AND Active__c = TRUE
            ORDER BY CreatedAt__c DESC
        ]);
        List<PortalCommerceApiInvoices.InvoiceList> allInvoices = new List<PortalCommerceApiInvoices.InvoiceList>();
        Integer calloutsLeft = Limits.getLimitCallouts() - Limits.getCallouts();
        System.debug('### IN: Callouts left: ' + calloutsLeft);
        for (InvoiceGroup__c invoiceGroup : invoiceGroups) {
            String nextId = null;
            calloutsLeft = Limits.getLimitCallouts() - Limits.getCallouts();
            if (calloutsLeft <= 2) {
                System.debug('### No callouts left. Skipping invoice group: ' + invoiceGroup.Name + ' (' + invoiceGroup.AtlassianInvoiceGroupId__c + ')');
                break;
            }
            do {
                System.debug('### Fetching invoices for invoice group: ' + invoiceGroup.Name + ' (' + invoiceGroup.AtlassianInvoiceGroupId__c + ')');
                PortalCommerceApiInvoices.InvoiceList invoices = apiInvoices.getPaidInvoices(acc.CV_Subsidiary__c, invoiceGroup.AtlassianInvoiceGroupId__c, INVOICE_PAGE_SIZE, nextId, lastNdays);
                System.debug('### Fetched ' + invoices.data.size() + ' invoices of max 50. nextId = ' + invoices.nextId);
                allInvoices.add(invoices);
                nextId = invoices.nextId;
                calloutsLeft--;
            } while (nextId != null && calloutsLeft > 0);
        }
        System.debug('### OUT: Callouts left: ' + calloutsLeft);
        prepareInvoicesForDisplay(allInvoices, acc.CV_Subsidiary__c);
        return allInvoices;
    }

    static private void prepareInvoicesForDisplay(List<PortalCommerceApiInvoices.InvoiceList> allInvoices, String office) {
        for (PortalCommerceApiInvoices.InvoiceList invoices : allInvoices) {
            if (invoices.data == null) {
                continue;
            }
            for (PortalCommerceApiInvoices.InvoiceInfo invoice : invoices.data) {
                invoice.office = office;
            }
        }
    }

    static private void trimInvoicesForViewer(List<PortalCommerceApiInvoices.InvoiceInfo> invoices) {
        for (PortalCommerceApiInvoices.InvoiceInfo invoice : invoices) {
            if (invoice.items == null) {
                invoice.items = new List<PortalCommerceApiInvoices.InvoiceItem>();
                continue;
            }
            if (invoice.items.size() > INVOICE_VIEWER_MAX_LINE_ITEMS) {
                invoice.totalItemCount = invoice.items.size();
                invoice.itemsTruncated = true;
                List<PortalCommerceApiInvoices.InvoiceItem> trimmed = new List<PortalCommerceApiInvoices.InvoiceItem>();
                for (Integer i = 0; i < INVOICE_VIEWER_MAX_LINE_ITEMS; i++) {
                    trimmed.add(invoice.items[i]);
                }
                invoice.items = trimmed;
            }
        }
    }

    static private Boolean isCalloutSizeLimitError(String error) {
        return error != null && error.contains('6000000');
    }

    static private InvoicePageResult buildOversizedInvoiceResult(
        InvoicePageResult result,
        String invoiceId,
        String office,
        Integer groupIndex
    ) {
        result.invoiceGroupIndex = groupIndex;
        result.hasMore = false;
        result.nextId = null;
        result.missingAccountId = false;
        if (String.isNotBlank(invoiceId)) {
            PortalCommerceApiInvoices.InvoiceInfo placeholder = new PortalCommerceApiInvoices.InvoiceInfo();
            placeholder.id = invoiceId;
            placeholder.invoiceNumber = 'Too large to load';
            placeholder.status = 'N/A';
            placeholder.office = office;
            placeholder.items = new List<PortalCommerceApiInvoices.InvoiceItem>();
            placeholder.tooLargeToLoad = true;
            placeholder.loadError = 'This invoice exceeds the Salesforce 6 MB API response limit. Use Preview or the Atlassian Partner Portal to view it.';
            result.data = new List<PortalCommerceApiInvoices.InvoiceInfo>{ placeholder };
        }
        result.error = 'One or more invoices exceed the Salesforce 6 MB API response limit and could not be loaded in full.';
        return result;
    }

    @AuraEnabled
    static public PortalCommerceApiInvoices.InvoiceInfo getInvoice(String opportunityId, String invoiceId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiInvoices.InvoiceInfo theInvoice = apiInvoices.getInvoice(opp.Account.CV_Subsidiary__c, invoiceId);
        if (theInvoice == null) {
            return null;
        }
        theInvoice.office = opp.Account.CV_Subsidiary__c;
        return theInvoice;
    }

    @AuraEnabled
    static public PortalCommerceApiOrders.OrderInfo getOrder(String opportunityId, String orderId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiOrders.OrderInfo theOrder = apiOrders.getOrder(opp.Account.CV_Subsidiary__c, orderId);
        if (theOrder == null) {
            return null;
        }
        theOrder.office = opp.Account.CV_Subsidiary__c;
        return theOrder;
    }

    @AuraEnabled
    static public PortalCommerceApiOrders.OrderInfo getOrderPreview(String opportunityId, String quoteId, Integer quoteVersion) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiOrders.OrderInfo theOrder = apiOrders.getOrderPreview(opp.Account.CV_Subsidiary__c, quoteId, quoteVersion);
        if (theOrder == null) {
            return null;
        }
        theOrder.office = opp.Account.CV_Subsidiary__c;
        return theOrder;
    }

    @AuraEnabled
    static public PortalCommerceApiEntitlements.EntitlementDisplayInfo getEntitlementDisplayInfo(String opportunityId, String entitlementId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiEntitlements.EntitlementDisplayInfo entitlementDisplayInfo = apiEntitlements.getEntitlementDisplayInfo(opp.Account.CV_Subsidiary__c, entitlementId);
        return entitlementDisplayInfo;
    }

    @AuraEnabled
    static public PortalCommerceApiEntitlements.EntitlementDetails getEntitlementDetails(String opportunityId, String entitlementId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiEntitlements.EntitlementDetails entitlementDetails = apiEntitlements.getEntitlementDetails(opp.Account.CV_Subsidiary__c, entitlementId);
        return entitlementDetails;
    }

    @AuraEnabled
    static public PortalCommerceApiEntitlements.EntitlementPartnerInfo getEntitlementPartnerInfo(String opportunityId, String entitlementId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiEntitlements.EntitlementPartnerInfo entitlementPartnerInfo = apiEntitlements.getEntitlementPartnerInfo(opp.Account.CV_Subsidiary__c, entitlementId);
        return entitlementPartnerInfo;
    }

    @AuraEnabled
    static public String getQuotePdfStatic(String office, String quoteId) {
        return apiQuotes.getQuotePdf(office, quoteId);
    }

    @AuraEnabled
    static public String getInvoicePdfStatic(String office, String invoiceId) {
        return apiInvoices.getInvoicePdf(office, invoiceId);
    }

    public class InvoicePageResult {
        @AuraEnabled public List<PortalCommerceApiInvoices.InvoiceInfo> data { get; set; }
        @AuraEnabled public String nextId { get; set; }
        @AuraEnabled public Integer invoiceGroupIndex { get; set; }
        @AuraEnabled public Boolean hasMore { get; set; }
        @AuraEnabled public String error { get; set; }
        @AuraEnabled public Boolean missingAccountId { get; set; }

        public InvoicePageResult() {
            data = new List<PortalCommerceApiInvoices.InvoiceInfo>();
            hasMore = false;
            missingAccountId = false;
        }
    }
}