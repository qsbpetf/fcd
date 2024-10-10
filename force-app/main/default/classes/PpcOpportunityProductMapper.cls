/**
 * Created by peterfriberg on 2024-09-03.
 */

public with sharing class PpcOpportunityProductMapper {

    private static PpcOpportunityProductMapper instance;

    public static PpcOpportunityProductMapper getInstance() {
        if (instance == null) {
            instance = new PpcOpportunityProductMapper();
        }
        return instance;
    }

    public List<OpportunityLineItem> mapProducts(PortalCommerceApiQuotes.QuoteInfo quoteInfo, Opportunity opp, Double conversionFactor, OpportunityProductMapper.LogData log) {
        PpcPortalProductMapper portalProductMapper = PpcPortalProductMapper.getInstance();
        PpcOpportunityProductMapper oppProductMapper = PpcOpportunityProductMapper.getInstance();

        List<OpportunityLineItem> opptyProductsToInsert = new List<OpportunityLineItem>();
        Map<String, Product2> mappedProducts = new Map<String, Product2>();
        List<PortalCommerceApiQuotes.BillLineItem> quoteLines = new List<PortalCommerceApiQuotes.BillLineItem>();
        Set<Id> productIds = new Set<Id>();

        for (PortalCommerceApiQuotes.BillLineItem quoteLine : quoteInfo.upcomingBills.lines) {
            PortalProductMapper.MappingResult mapResult = portalProductMapper.mapProduct(quoteLine.description);
            if (mapResult.found) {
                System.debug('  -- Product found: ' + mapResult);
                log.productLog.add(String.valueOf(mapResult));

                if (mapResult.globalSEN) {
                    // globalSEN = orderLine.supportEntitlementNumber;
                    // System.debug('* Found common SEN: ' + globalSEN);
                } else {
                    if (mapResult.zeroSEN) {
                        // orderLine.supportEntitlementNumber = '0';
                        System.debug('* Found zero SEN:');
                    }
                    mappedProducts.put(quoteLine.description, mapResult.product);
                    productIds.add(mapResult.product.Id);
                    quoteLines.add(quoteLine);
                }
            } else {
                System.debug('  -- Product NOT found: ' + mapResult);
                log.productLog.add(String.valueOf(mapResult));
            }
        }

        Map<Id, PricebookEntry> pbeByProductId = getPriceBookEntriesMappedByProductId(productIds, opp);

        for (PortalCommerceApiQuotes.BillLineItem quoteLine : quoteLines) {
            Product2 mappedProduct = mappedProducts.get(quoteLine.description);
            PricebookEntry pbe = pbeByProductId.get(mappedProduct.Id);
            if (pbe != null) {
                OpportunityLineItem oppProduct = oppProductMapper.mapOpportunityLineItem(pbe, opp.Id, quoteLine, conversionFactor);
                if (oppProduct != null) {
                    opptyProductsToInsert.add(oppProduct);
                    log.pbeLog.add('PricebookEntry FOUND for product: ' + mappedProduct.Name + ' OLI = ' + JSON.serialize(oppProduct));
                } else {
                    System.debug('Skipping zero unit price order line: ' + quoteLine.description);
                    log.pbeLog.add('Skipping zero unit price order line for product: ' + quoteLine.description);
                }
            } else {
                System.debug('No matching PricebookEntry found for Product: ' + mappedProduct);
                log.pbeLog.add('MISSING PricebookEntry for product: ' + mappedProduct.Name + ' PB=' + opp.Pricebook2.Name + ' CURR=' + opp.CurrencyIsoCode);
                log.errorLog.add('MISSING PricebookEntry for product: ' + mappedProduct.Name + ' PB=' + opp.Pricebook2.Name + ' CURR=' + opp.CurrencyIsoCode);
            }
        }

        return opptyProductsToInsert;
    }

    private static Map<Id, PricebookEntry> getPriceBookEntriesMappedByProductId(Set<Id> productIds, Opportunity opp) {
        Map<Id, PricebookEntry> pbeByProductId = new Map<Id, PricebookEntry>();
        System.debug([
            SELECT Id, Product2Id, Pricebook2Id, CurrencyIsoCode
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
            AND Pricebook2Id = :opp.Pricebook2Id
            AND CurrencyIsoCode = :opp.CurrencyIsoCode
        ]);
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

    public OpportunityLineItem mapOpportunityLineItem(PricebookEntry pbEntry, Id oppId, PortalCommerceApiQuotes.BillLineItem quoteLine, Double conversionFactor) {
        OpportunityLineItem oli = new OpportunityLineItem();

        System.debug(JSON.serializePretty(quoteLine));

        if (quoteLine.subTotal == 0) {
            System.debug('Skipping zero unit price order line: ' + quoteLine.description);
            return null;
        }

        oli.PricebookEntryId = pbEntry.Id;
        oli.Product2Id = pbEntry.Product2Id;
        oli.OpportunityId = oppId;
        Long startsAt = quoteLine?.period?.startsAt;
        Long endsAt = quoteLine?.period?.endsAt;
        // oli.License_Start_date__c = (orderLine.startDate == null) ? Date.today() : orderLine.startDate; // slide 8 in documentation "Where dates = null"
        oli.License_Start_date__c = (startsAt != null) ? Datetime.newInstance(startsAt).date() : Date.today();
        // Date endDate = (orderLine.endDate == null) ? Date.today().addMonths(orderLine.maintenanceMonths) : orderLine.endDate;
        // oli.License_end_date__c = endDate;
        oli.License_end_date__c = (endsAt != null) ? Datetime.newInstance(endsAt).date() : null;
        oli.Additional_Info__c = quoteLine.description;
        oli.Cloud_Site_Name__c = quoteLine.entName;
        // oli.SEN__c = quoteLine.entSlug;
        oli.Entitlement_Number__c = quoteLine.entSlug;
        oli.Editable_Cost_Price_in_Dollars__c = quoteLine.total / 100;
        oli.User_Count__c = quoteLine.quantity;
//        oli.Atlassian_Price_Adjustment__c = quoteLine.priceAdjustment;
//        oli.Atlassian_Upgrade_Credit__c = quoteLine.upgradeCredit;
//        oli.Atlassian_Partner_Discount__c = quoteLine.partnerDiscountTotal;
//        oli.Atlassian_Loyalty_Discount__c = quoteLine.loyaltyDiscountTotal;
        oli.QuoteOriginalProduct__c = quoteLine.description;
        oli.Quantity = 1;
        oli.Editable_Unit_List_Price_in_USD__c = quoteLine.subTotal / 100.0;
        // oli.Renewal__c = convertRenewal(quoteLine.saleType, quoteLine.discountReason);
        oli.Renewal__c = 'Renewal (CV Owned)';

        return oli;
    }
}