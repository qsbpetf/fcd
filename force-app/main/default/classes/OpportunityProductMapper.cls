public with sharing class OpportunityProductMapper {
    private static OpportunityProductMapper instance;

    public static OpportunityProductMapper getInstance() {
        if (instance == null) {
            instance = new OpportunityProductMapper();
        }
        return instance;
    }

    /**
     * Maps multiple Products and OrderLines to Salesforce Opportunity Products.
     *
     * @param mappedProducts - The list of Salesforce products that the partner portal products map to
     * @param oppId - Salesforce Opportunity ID where partner portal product JSON are inserted
     * @param orderLines - List of fields from partner portal products for mapping to Opportunity Products
     *
     * @return The list of Salesforce OpportunityLineItem (Opportunity Products) results of the mapping.
     */
    public List<OpportunityLineItem> mapProducts(List<Product2> mappedProducts, String oppId, List<PortalJsonParser.OrderLine> orderLines) {
        List<OpportunityLineItem> opportunityLineItems = new List<OpportunityLineItem>();

        try {
            // Get the oppty with PbId and currency from SF
            Opportunity oppty = [SELECT Id, Pricebook2Id, CurrencyIsoCode 
                                 FROM Opportunity 
                                 WHERE Id = :oppId 
                                 LIMIT 1];

            // Collect Product2 ids in set
            Set<Id> product2Ids = new Set<Id>();
            for (Product2 product : mappedProducts) {
                product2Ids.add(product.Id);
            }

            // Get PriceBookEntries and store in map
            Map<Id, PricebookEntry> pricebookEntries = new Map<Id, PricebookEntry>();
            for (PricebookEntry pbe : [SELECT Id, Product2Id, Pricebook2Id, CurrencyIsoCode
                                        FROM PricebookEntry
                                        WHERE Product2Id IN :product2Ids
                                        AND Pricebook2Id = :oppty.Pricebook2Id
                                        AND CurrencyIsoCode = :oppty.CurrencyIsoCode]) {

                pricebookEntries.put(pbe.Product2Id, pbe);
            }

            // Create opp line item, iterate over orderline and get pricebookEntry
            for (Integer i = 0; i < orderLines.size(); i++) {
                Product2 mappedProduct = mappedProducts[i];
                PortalJsonParser.OrderLine orderLine = orderLines[i];

                // Find pbe
                PricebookEntry pbEntry = pricebookEntries.get(mappedProduct.Id);

                if (pbEntry != null) {
                    OpportunityLineItem mappedOppLineItem = mapOpportunityLineItem(pbEntry, oppty, orderLine);
                    opportunityLineItems.add(mappedOppLineItem);
                } else {
                    System.debug('No matching PricebookEntry found for Product2 Id: ' + mappedProduct.Id);
                }
            }
        } catch (Exception e) {
            System.debug('Error mapping products: ' + e.getMessage());
        }

        return opportunityLineItems; // or insert opportunity products
    }

    // Map OpportunityProduct
    @TestVisible
    private OpportunityLineItem mapOpportunityLineItem(PricebookEntry pbEntry, Opportunity oppty, PortalJsonParser.OrderLine orderLine) {
        OpportunityLineItem opl = new OpportunityLineItem();

        opl.PricebookEntryId = pbEntry.Id;
        opl.Product2Id = pbEntry.Product2Id;
        opl.OpportunityId = oppty.Id;
        // opl.License_Start_date__c = (orderLine.startDate == null) ? Date.today() : orderLine.startDate; // slide 8 in documentation "Where dates = null"
        // Date endDate = (orderLine.endDate == null) ? Date.today().addMonths(orderLine.maintenanceMonths) : orderLine.endDate; 
        // opl.License_end_date__c = endDate;
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
        opl.Atlassian_Upgrade_Credit__c = orderLine.upgradeCredit;
        opl.Atlassian_Partner_Discount__c = orderLine.partnerDiscountTotal;
        opl.Atlassian_Loyalty_Discount__c = orderLine.loyaltyDiscountTotal;

        return opl;
    }
}
