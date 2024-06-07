public with sharing class OpportunityProductMapper {
    private static OpportunityProductMapper instance;

    public static OpportunityProductMapper getInstance() {
        if (instance == null) {
            instance = new OpportunityProductMapper();
        }
        return instance;
    }

    /**
     * Maps a Product, Opportunity and OrderLine to a Salesforce Opportunity Product.
     *
     * @param mappedProduct - The Salesforce product that the partner portal product maps to
     * @param oppId - Salesforce Opportunity where partner portal product JSON is inserted
     * @param orderLine - Fields from partner portal product for mapping to Opportunity Product
     *
     * @return The Salesforce Opportunity result of the mapping. 
     */
    public List<OpportunityLineItem> mapProducts(Product2 mappedProduct, String oppId, PortalJsonParser.OrderLine orderLine){

        try{
        //Get oppty from SF
        Opportunity oppty = [SELECT Id, PriceBook2Id, CurrencyIsoCode 
                             FROM Opportunity 
                             WHERE Id = :oppId 
                             LIMIT 1];

        //get Product2 from mappingResult 
        // Product2 product = [SELECT Id, Name
        //                     FROM Product2
        //                     WHERE Id = :mappedProduct.Id LIMIT 1];

        //Get PriceBookEntry
        PricebookEntry pbEntry = [SELECT Id, Product2Id
                                FROM PricebookEntry 
                                WHERE Product2Id = :mappedProduct.Id 
                                AND Pricebook2Id = :oppty.Pricebook2Id 
                                AND CurrencyIsoCode = :oppty.CurrencyIsoCode 
                                LIMIT 1];
        
        OpportunityLineItem mappedOppLineItem = mapOpportunityLineItem(pbEntry, oppty, orderLine);
    }
    catch (Exception e) {
        System.debug('Error mapping products: ' + e.getMessage());
    }

        return mappedOppLineItem;
        
    }

    // Map OpportunityProduct
    @TestVisible
    private OpportunityLineItem mapOpportunityLineItem(PricebookEntry pbEntry, Opportunity oppty,PortalJsonParser.OrderLine orderLine){

        OpportunityLineItem opl = new OpportunityLineItem();

        opl.PricebookEntryId = pbEntryId.Id;
        opl.Product2Id = pbEntry.Product2Id;
        opl.OpportunityId = oppty.Id;
        opl.Pricebook2Id = oppty.Pricebook2Id;
        opl.currencyIsoCode = oppty.CurrencyIsoCode;
        opl.License_Start_date__c = orderLine.startDate;
        opl.License_end_date__c = orderLine.endDate;
        opl.Additional_Info__c = orderLine.description;
        opl.Cloud_Site_Name__c = orderLine.cloudSiteHostname;
        opl.SEN__c = orderLine.supportEntitlementNumber;
        opl.Entitlement_Number__c = orderLine.entitlementNumber;
        opl.Renewal__c = orderLine.saleType;
        opl.Editable_Unit_List_Price_in_USD__c = orderLine.unitPrice;
        opl.Editable_Cost_Price_in_Dollars__c = orderLine.total;
        opl.User_Count__c = orderLine.unitCount;
        opl.Atlassian_Price_Adjustment__c = orderLine.priceAdjustment;
        opl.Atlassian_Upgrade_Credit__c = orderline.upgradeCredit;
        opl.Atlassian_Partner_Discount__c = orderLine.partnerDiscountTotal;
        opl.Atlassian_Loyalty_Discount__c = orderLine.loyaltyDiscountTotal;

        return opl;
    }


    

}