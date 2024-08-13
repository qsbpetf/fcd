/**
 * Created by peterfriberg on 2024-08-13.
 */

public with sharing class PortalCommerceApiController {

    @AuraEnabled
    static public PortalCommerceApiQuotes.QuoteList getQuotes(String opportunityId) {
        Opportunity opp = [SELECT Id, AccountId, Account.Company_ID__c FROM Opportunity WHERE Id = :opportunityId];
        String transactionAccountId = opp.Account.Company_ID__c;

        /// HARD CODED!!!
        transactionAccountId = '798870d9-acb4-4f8b-a037-937152c5e874';

        PortalCommerceApiQuotes.QuoteList quotes = PortalCommerceApiQuotes.getQuotesStatic(25, null, transactionAccountId);
        return quotes;
    }
}