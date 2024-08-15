/**
 * Created by peterfriberg on 2024-08-13.
 */

public with sharing class PortalCommerceApiController {

    @AuraEnabled
    static public PortalCommerceApiQuotes.QuoteList getQuotes(String opportunityId) {
        Opportunity opp = [SELECT Id, AccountId, Account.AtlassianAccountId__c FROM Opportunity WHERE Id = :opportunityId];
        String transactionAccountId = opp.Account.AtlassianAccountId__c;
        if (transactionAccountId == null) {
            PortalCommerceApiQuotes.QuoteList quotes = new PortalCommerceApiQuotes.QuoteList();
            quotes.missingAccountId = true;
            return quotes;
        }
        // transactionAccountId = '798870d9-acb4-4f8b-a037-937152c5e874';

        PortalCommerceApiQuotes.QuoteList quotes = PortalCommerceApiQuotes.getQuotesStatic(25, null, transactionAccountId);
        return quotes;
    }

    @AuraEnabled
    static public PortalCommerceApiInvoices.InvoiceList getInvoices(String accountId) {
        Account acc = [SELECT Id, AtlassianAccountId__c FROM Account WHERE Id = :accountId];
        String transactionAccountId = acc.AtlassianAccountId__c;
        if (transactionAccountId == null) {
            PortalCommerceApiInvoices.InvoiceList invoices = new PortalCommerceApiInvoices.InvoiceList();
            invoices.missingAccountId = true;
            return invoices;
        }
        PortalCommerceApiInvoices.InvoiceList invoices = PortalCommerceApiInvoices.getInvoicesStatic(25, null, transactionAccountId);
        return invoices;
    }
}