/**
 * Created by peterfriberg on 2024-08-13.
 */

public with sharing class PortalCommerceApiController {

    @AuraEnabled
    static public PortalCommerceApiQuotes.QuoteList getQuotes(String opportunityId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiQuotes.QuoteList quotes = PortalCommerceApiQuotes.getQuotesStatic(opp.Account.CV_Subsidiary__c, 25, null);
        return quotes;
    }

    @AuraEnabled
    static public PortalCommerceApiQuotes.QuoteInfo getQuote(String opportunityId, String quoteId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiQuotes.QuoteInfo theQuote = PortalCommerceApiQuotes.getQuoteStatic(opp.Account.CV_Subsidiary__c, quoteId);
        theQuote.office = opp.Account.CV_Subsidiary__c;
        return theQuote;
    }

//    @AuraEnabled
//    static public String importQuote(String opportunityId, String quoteInfo) {
//        System.debug(quoteInfo);
//        PortalCommerceApiQuotes.QuoteInfo quoteData = (PortalCommerceApiQuotes.QuoteInfo) JSON.deserialize(quoteInfo, PortalCommerceApiQuotes.QuoteInfo.class);
//        System.debug(quoteData);
//        return 'OK';
//    }

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
                PortalCommerceApiInvoices.InvoiceList invoices = PortalCommerceApiInvoices.getInvoicesStatic(acc.CV_Subsidiary__c, invoiceGroup.AtlassianInvoiceGroupId__c, 50, nextId);
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
        PortalCommerceApiEntitlements.EntitlementDisplayInfo entitlementDisplayInfo = PortalCommerceApiEntitlements.getEntitlementDisplayInfoStatic(opp.Account.CV_Subsidiary__c, entitlementId);
        return entitlementDisplayInfo;
    }

    @AuraEnabled
    static public PortalCommerceApiEntitlements.EntitlementDetails getEntitlementDetails(String opportunityId, String entitlementId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c, Account.CV_Subsidiary__c FROM Opportunity WHERE Id = :opportunityId];
        PortalCommerceApiEntitlements.EntitlementDetails entitlementDetails = PortalCommerceApiEntitlements.getEntitlementDetailsStatic(opp.Account.CV_Subsidiary__c, entitlementId);
        return entitlementDetails;
    }
}