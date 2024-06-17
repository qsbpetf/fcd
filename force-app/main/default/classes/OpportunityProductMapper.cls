public with sharing class OpportunityProductMapper {

    private static final Map<String, String> SALETYPE_MAPPING = new Map<String, String> {
        'NEW' => 'New',
        'RENEWAL' => 'Renewal (CV Owned)',
        'RENEWAL_NEW' => 'Renewal (New to CV)',
        'UPGRADE' => 'Upgrade (Same Platform)',
        'DOWNGRADE' => 'Downgrade (Same Platform)'
    };

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
     * @param orderInfo - The list of fields from partner portal products for mapping to Opportunity Products
     * @param opp - Salesforce Opportunity where partner portal product JSON are inserted
     * @param conversionFactor - Conversion factor for currency conversion
     * @param log - Log of the mapping process
     *
     * @return The list of Salesforce OpportunityLineItem (Opportunity Products) results of the mapping.
     */
    public List<OpportunityLineItem> mapProducts(PortalJsonParser.OrderInformation orderInfo, Opportunity opp, Double conversionFactor, OpportunityProductMapper.LogData log) {
        PortalProductMapper portalProductMapper = PortalProductMapper.getInstance();
        OpportunityProductMapper oppProductMapper = OpportunityProductMapper.getInstance();

        List<OpportunityLineItem> opptyProductsToInsert = new List<OpportunityLineItem>();
        Map<String, Product2> mappedProducts = new Map<String, Product2>();
        List<PortalJsonParser.OrderLine> orderLines = new List<PortalJsonParser.OrderLine>();
        Set<Id> productIds = new Set<Id>();

        for (PortalJsonParser.OrderLine orderLine : orderInfo.orderItems) {
            PortalProductMapper.MappingResult mapResult = portalProductMapper.mapProduct(orderLine.productName, orderLine.platform, orderLine.edition);
            if (mapResult.found) {
                System.debug('  -- Product found: ' + mapResult);
                log.productLog.add(String.valueOf(mapResult));
                mappedProducts.put(productAsKey(orderLine.productName, orderLine.platform, orderLine.edition), mapResult.product);
                productIds.add(mapResult.product.Id);
                orderLines.add(orderLine);
            }
        }

        Map<Id, PricebookEntry> pbeByProductId = getPriceBookEntriesMappedByProductId(productIds, opp);

        for (PortalJsonParser.OrderLine orderLine : orderLines) {
            Product2 mappedProduct = mappedProducts.get(productAsKey(orderLine.productName, orderLine.platform, orderLine.edition));
            PricebookEntry pbe = pbeByProductId.get(mappedProduct.Id);
            if (pbe != null) {
                OpportunityLineItem oppProduct = oppProductMapper.mapOpportunityLineItem(pbe, opp.Id, orderLine, conversionFactor);
                if (oppProduct != null) {
                    opptyProductsToInsert.add(oppProduct);
                    log.pbeLog.add('PricebookEntry FOUND for product: ' + mappedProduct.Name);
                } else {
                    System.debug('Skipping zero total order line: ' + orderLine.productName);
                    log.pbeLog.add('Skipping zero total order line for product: ' + orderLine.productName);
                }
            } else {
                System.debug('No matching PricebookEntry found for Product: ' + mappedProduct);
                log.pbeLog.add('MISSING PricebookEntry for product: ' + mappedProduct.Name + ' PB=' + opp.Pricebook2.Name + ' CURR=' + opp.CurrencyIsoCode);
            }
        }

        return opptyProductsToInsert;
    }

    private static String productAsKey(String productName, String platform, String edition) {
        return productName + ':' + platform + ':' + edition;
    }

    private static Map<Id, PricebookEntry> getPriceBookEntriesMappedByProductId(Set<Id> productIds, Opportunity opp) {
        Map<Id, PricebookEntry> pbeByProductId = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, Pricebook2Id, CurrencyIsoCode
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
            AND Pricebook2Id = :opp.Pricebook2Id
            AND CurrencyIsoCode = :opp.CurrencyIsoCode
        ]) {
            pbeByProductId.put(pbe.Product2Id, pbe);
        }

        return pbeByProductId;
    }

    public OpportunityLineItem mapOpportunityLineItem(PricebookEntry pbEntry, Id oppId, PortalJsonParser.OrderLine orderLine, Double conversionFactor) {
        OpportunityLineItem oli = new OpportunityLineItem();

        System.debug(JSON.serializePretty(orderLine));

        if (orderLine.total == 0.00) {
            System.debug('Skipping zero total order line: ' + orderLine.productName);
            return null;
        }

        oli.PricebookEntryId = pbEntry.Id;
        oli.Product2Id = pbEntry.Product2Id;
        oli.OpportunityId = oppId;
        // oli.License_Start_date__c = (orderLine.startDate == null) ? Date.today() : orderLine.startDate; // slide 8 in documentation "Where dates = null"
        // Date endDate = (orderLine.endDate == null) ? Date.today().addMonths(orderLine.maintenanceMonths) : orderLine.endDate; 
        // oli.License_end_date__c = endDate;
        oli.License_Start_date__c = orderLine.startDate;
        oli.License_end_date__c = orderLine.endDate;
        oli.Additional_Info__c = orderLine.description;
        oli.Cloud_Site_Name__c = orderLine.cloudSiteHostname;
        oli.SEN__c = orderLine.supportEntitlementNumber;
        oli.Entitlement_Number__c = orderLine.entitlementNumber;
        oli.Renewal__c = convertRenewal(orderLine.saleType, orderLine.discountReason);
        oli.Editable_Unit_List_Price_in_USD__c = orderLine.unitPrice;
        oli.Editable_Cost_Price_in_Dollars__c = orderLine.total;
        oli.User_Count__c = orderLine.unitCount;
        oli.Atlassian_Price_Adjustment__c = orderLine.priceAdjustment;
        oli.Atlassian_Upgrade_Credit__c = orderLine.upgradeCredit;
        oli.Atlassian_Partner_Discount__c = orderLine.partnerDiscountTotal;
        oli.Atlassian_Loyalty_Discount__c = orderLine.loyaltyDiscountTotal;
        oli.QuoteOriginalProduct__c = orderLine.productName;
        oli.Quantity = 1;

        return oli;
    }

    private static Double convertCurrency(Double amount, Double conversionFactor) {
        return (amount != null) ? amount * conversionFactor : null;
    }

    private static String convertRenewal(String value, String discountReason) {
        String key = value;
        if (value.equalsIgnoreCase('RENEWAL') && discountReason != null && discountReason.equalsIgnoreCase('RENEWAL_PREVIOUSLY_DIFFERENT_EXPERT')) {
            key = 'RENEWAL_NEW';
        }
        String result = SALETYPE_MAPPING.get(key);
        System.debug('** SaleType: ' + key + ' -> ' + result);
        return (result != null) ? result : key;
    }

    public class LogData {
        @AuraEnabled public List<String> productLog;
        @AuraEnabled public List<String> pbeLog;

        public LogData() {
            this.productLog = new List<String>();
            this.pbeLog = new List<String>();
        }
    }
}
