public with sharing class PromoCodeController {

    @AuraEnabled(Cacheable=true)
    public static List<PromotionCode__c> getActivePromoCodes(String partnerName) {
        try {
            String query = 'SELECT Id, PromoCode__c, StartDate__c, EndDate__c, Partner__c, IsActive__c ' +
                'FROM PromotionCode__c ' +
                'WHERE IsActive__c = true';

            if (String.isNotBlank(partnerName)) {
                query += ' AND Partner__c LIKE :partnerName';
                partnerName = '%' + partnerName + '%';
            }

            query += ' ORDER BY StartDate__c DESC';

            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving promo codes: ' + e.getMessage());
        }
    }
}