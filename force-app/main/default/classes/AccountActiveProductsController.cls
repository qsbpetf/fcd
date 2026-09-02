public with sharing class AccountActiveProductsController {

    private static final Integer MAX_LIMIT = 1000;

    @AuraEnabled(cacheable=true)
    public static ActiveProductsResult getActiveProducts(Id accountId, Integer limitSize) {
        if (accountId == null) {
            throw new AuraHandledException('Account ID is required.');
        }

        // null / 0 / negatif gelirse tüm listeyi döndür (max 1000)
        Integer effectiveLimit = (limitSize == null || limitSize <= 0)
            ? MAX_LIMIT
            : Math.min(limitSize, MAX_LIMIT);

        ActiveProductsResult result = new ActiveProductsResult();

        result.records = [
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
            LIMIT :effectiveLimit
        ];

        result.totalCount = [
            SELECT COUNT()
            FROM OpportunityLineItem
            WHERE Opportunity.AccountId = :accountId
              AND Opportunity.StageName = 'Order'
        ];

        return result;
    }

    public class ActiveProductsResult {
        @AuraEnabled public List<OpportunityLineItem> records;
        @AuraEnabled public Integer totalCount;
    }
}