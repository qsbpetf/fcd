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
    static public PortalCommerceApiInvoices.InvoiceList getInvoices(String accountId) {
        Account acc = [SELECT Id, AtlassianAccountId__c, CV_Subsidiary__c FROM Account WHERE Id = :accountId];
        String transactionAccountId = acc.AtlassianAccountId__c;
//        if (transactionAccountId == null) {
//            PortalCommerceApiInvoices.InvoiceList invoices = new PortalCommerceApiInvoices.InvoiceList();
//            invoices.missingAccountId = true;
//            invoices.error = 'No invoices found';
//            return invoices;
//        }
        PortalCommerceApiInvoices.InvoiceList invoices = PortalCommerceApiInvoices.getInvoicesStatic(acc.CV_Subsidiary__c, 25, null);
        return invoices;
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