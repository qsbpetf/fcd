public with sharing class AccountActiveProductsController {

    @AuraEnabled(cacheable=true)
    public static List<OpportunityLineItem> getActiveProducts(Id accountId) {
        if (accountId == null) {
            throw new AuraHandledException('Account ID is required.');
        }

        return [
            SELECT
                Id,
                Product2.Name,
                Quantity,
                User_Count__c,
                License_Start_date__c,
                License_end_date__c,
                Renewal__c,
                Opportunity.Name,
                Opportunity.CloseDate
            FROM OpportunityLineItem
            WHERE Opportunity.AccountId = :accountId
              AND Opportunity.StageName = 'Order'
            ORDER BY License_end_date__c DESC NULLS LAST
            LIMIT 1000
        ];
    }
}