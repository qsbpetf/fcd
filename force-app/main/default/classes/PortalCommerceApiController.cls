/**
 * Created by peterfriberg on 2024-08-13.
 */

public with sharing class PortalCommerceApiController {

    @TestVisible static private PortalCommerceApiQuotes apiQuotes = PortalCommerceApiQuotes.getInstance();
    @TestVisible static private PortalCommerceApiEntitlements apiEntitlements = PortalCommerceApiEntitlements.getInstance();
    @TestVisible static private PortalCommerceApiInvoices apiInvoices = PortalCommerceApiInvoices.getInstance();

    public static void setApiQuotes(PortalCommerceApiQuotes api) {
        apiQuotes = api;
    }

    public static void setApiEntitlements(PortalCommerceApiEntitlements api) {
        apiEntitlements = api;
    }

    public static void setApiInvoices(PortalCommerceApiInvoices api) {
        apiInvoices = api;
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
                PortalCommerceApiInvoices.InvoiceList invoices = apiInvoices.getInvoices(acc.CV_Subsidiary__c, invoiceGroup.AtlassianInvoiceGroupId__c, 50, nextId);
                System.debug('### Fetched ' + invoices.data.size() + ' invoices of max 50. nextId = ' + invoices.nextId);
                allInvoices.add(invoices);
                nextId = invoices.nextId;
                calloutsLeft--;
            } while (nextId != null && calloutsLeft > 0);
        }
        System.debug('### OUT: Callouts left: ' + calloutsLeft);
        return allInvoices;
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
    static public String getQuotePdfStatic(String office, String quoteId) {
        return apiQuotes.getQuotePdf(office, quoteId);
    }
}