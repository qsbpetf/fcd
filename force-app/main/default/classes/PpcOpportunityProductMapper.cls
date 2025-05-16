/**
 * Created by peterfriberg on 2024-09-03.
 */

public with sharing class PpcOpportunityProductMapper {

    private static final PPC_InvoiceAutoImportSettings__c SETTING = PPC_InvoiceAutoImportSettings__c.getInstance();

    private static final Map<String, String> SALE_TYPE_MAPPING = new Map<String, String> {
        'NA' => 'Renewal (CV Owned)',
        'NEW' => 'New',
        'RENEW' => 'Renewal (CV Owned)',
        'RENEWAL' => 'Renewal (CV Owned)',
        'RENEWAL_NEW' => 'Renewal (New to CV)',
        'UPGRADE' => 'Upgrade (Same Platform)',
        'DOWNGRADE' => 'Downgrade (Same Platform)'
    };

    @TestVisible private static PpcOpportunityProductMapper instance;

    public static PpcOpportunityProductMapper getInstance() {
        if (instance == null) {
            instance = new PpcOpportunityProductMapper();
        }
        return instance;
    }

    /**
     * Maps products from a QUOTE to OpportunityLineItems
     *
     * @param quoteInfo - QuoteInfo object from the API
     * @param opp - Opportunity to map the products to
     * @param conversionFactor - Currency conversion factor
     * @param log - LogData object to store logs
     * @param mergeLineItems - Merge equal products into one OpportunityLineItem
     *
     * @return List of OpportunityLineItems
     */
    public List<OpportunityLineItem> mapProducts(
        PortalCommerceApiQuotes.QuoteInfo quoteInfo,
        Opportunity opp,
        Double conversionFactor,
        OpportunityProductMapper.LogData log,
        Boolean mergeLineItems)
    {
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
                log.errorLog.add('MISSING Product: ' + quoteLine.description);
            }
        }

        Map<Id, PricebookEntry> pbeByProductId = getPriceBookEntriesMappedByProductId(productIds, opp);

        for (PortalCommerceApiQuotes.BillLineItem quoteLine : quoteLines) {
            Product2 mappedProduct = mappedProducts.get(quoteLine.description);
            PricebookEntry pbe = pbeByProductId.get(mappedProduct.Id);
            if (pbe != null) {
                OpportunityLineItem oppProduct = oppProductMapper.mapQuoteLineToOpportunityLineItem(pbe, opp.Id, quoteLine, conversionFactor);
                if (oppProduct != null) {
                    opptyProductsToInsert.add(oppProduct);
                    log.pbeLog.add('PricebookEntry FOUND for product: ' + mappedProduct.Name + '  _____FROM: ' + quoteLine.description);
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

        if (mergeLineItems) {
            opptyProductsToInsert = mergeEqualProducts(opptyProductsToInsert, log);
            if (SETTING != null && SETTING.MergeDateRanges__c) {
                opptyProductsToInsert = mergeDateRanges(opptyProductsToInsert, log);
            }
        }

        Integer i = 1;
        for (OpportunityLineItem oli : opptyProductsToInsert) {
            log.successLog.add(
                'Resulting product (' + i + ') = ' + oli.Additional_Info__c +
                ', User Count: ' + oli.User_Count__c +
                ', Price (USD): ' + (oli.Editable_Unit_List_Price_in_USD__c != null ? oli.Editable_Unit_List_Price_in_USD__c.format() : '') +
                ', Cost Price (USD): ' + (oli.Editable_Cost_Price_in_Dollars__c != null ? oli.Editable_Cost_Price_in_Dollars__c.format() : '') +
                ', Product: ' + oli.Product2Id +
                ', PricebookEntry: ' + oli.PricebookEntryId +
                ', Start Date: ' + (oli.License_Start_date__c != null ? oli.License_Start_date__c.format() : '') +
                ', End Date: ' + (oli.License_end_date__c != null ? oli.License_end_date__c.format() : '') +
                ', Partner Disc:' + (oli.Atlassian_Partner_Discount__c != null ? oli.Atlassian_Partner_Discount__c.format() : '') +
                ', Entitlement Number: ' + oli.Entitlement_Number__c);
            i++;
        }

        return opptyProductsToInsert;
    }

    /**
     * Maps products from an INVOICE to OpportunityLineItems
     *
     * @param invoiceInfo InvoiceInfo object
     * @param opp Opportunity object
     * @param conversionFactor Currency conversion factor
     * @param log LogData object
     * @param mergeLineItems TRUE = Merge equal products into one OpportunityLineItem
     *
     * @return List of OpportunityLineItems
     */
    public List<OpportunityLineItem> mapProducts(
        PortalCommerceApiInvoices.InvoiceInfo invoiceInfo,
        Opportunity opp, Double conversionFactor,
        OpportunityProductMapper.LogData log,
        Boolean mergeLineItems)
    {
        PpcPortalProductMapper portalProductMapper = PpcPortalProductMapper.getInstance();
        PpcOpportunityProductMapper oppProductMapper = PpcOpportunityProductMapper.getInstance();

        List<OpportunityLineItem> opptyProductsToInsert = new List<OpportunityLineItem>();
        Map<String, Product2> mappedProducts = new Map<String, Product2>();
        List<PortalCommerceApiInvoices.InvoiceItem> invoiceLines = new List<PortalCommerceApiInvoices.InvoiceItem>();
        Set<Id> productIds = new Set<Id>();

        for (PortalCommerceApiInvoices.InvoiceItem invoiceLine : invoiceInfo.items) {
            PortalProductMapper.MappingResult mapResult = portalProductMapper.mapProduct(invoiceLine.description);
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
                    mappedProducts.put(invoiceLine.description, mapResult.product);
                    productIds.add(mapResult.product.Id);
                    invoiceLines.add(invoiceLine);
                }
            } else {
                System.debug('  -- Product NOT found: ' + mapResult);
                log.productLog.add(String.valueOf(mapResult));
                log.errorLog.add('MISSING Product: ' + invoiceLine.description);
            }
        }

        Map<Id, PricebookEntry> pbeByProductId = getPriceBookEntriesMappedByProductId(productIds, opp);

        for (PortalCommerceApiInvoices.InvoiceItem invoiceLine : invoiceLines) {
            Product2 mappedProduct = mappedProducts.get(invoiceLine.description);
            PricebookEntry pbe = pbeByProductId.get(mappedProduct.Id);
            if (pbe != null) {
                OpportunityLineItem oppProduct = oppProductMapper.mapInvoiceLineToOpportunityLineItem(pbe, opp.Id, invoiceLine, conversionFactor);
                if (oppProduct != null) {
                    opptyProductsToInsert.add(oppProduct);
                    log.pbeLog.add('PricebookEntry FOUND for product: ' + mappedProduct.Name + '  _____FROM: ' + invoiceLine.description);
                } else {
                    System.debug('Skipping zero unit price order line: ' + invoiceLine.description);
                    log.pbeLog.add('Skipping zero unit price order line for product: ' + invoiceLine.description);
                }
            } else {
                System.debug('No matching PricebookEntry found for Product: ' + mappedProduct);
                log.pbeLog.add('MISSING PricebookEntry for product: ' + mappedProduct.Name + ' PB=' + opp.Pricebook2.Name + ' CURR=' + opp.CurrencyIsoCode);
                log.errorLog.add('MISSING PricebookEntry for product: ' + mappedProduct.Name + ' PB=' + opp.Pricebook2.Name + ' CURR=' + opp.CurrencyIsoCode);
            }
        }

        if (mergeLineItems) {
            opptyProductsToInsert = mergeEqualProducts(opptyProductsToInsert, log);
            if (SETTING != null && SETTING.MergeDateRanges__c) {
                opptyProductsToInsert = mergeDateRanges(opptyProductsToInsert, log);
            }
        }

        Integer i = 1;
        for (OpportunityLineItem oli : opptyProductsToInsert) {
            log.successLog.add(
                'Resulting product (' + i + ') = ' + oli.Additional_Info__c +
                ', User Count: ' + oli.User_Count__c +
                ', Price (USD): ' + (oli.Editable_Unit_List_Price_in_USD__c != null ? oli.Editable_Unit_List_Price_in_USD__c.format() : '') +
                ', Cost Price (USD): ' + (oli.Editable_Cost_Price_in_Dollars__c != null ? oli.Editable_Cost_Price_in_Dollars__c.format() : '') +
                ', Product: ' + oli.Product2Id +
                ', PricebookEntry: ' + oli.PricebookEntryId +
                ', Start Date: ' + (oli.License_Start_date__c != null ? oli.License_Start_date__c.format() : '') +
                ', End Date: ' + (oli.License_end_date__c != null ? oli.License_end_date__c.format() : '') +
                ', Partner Disc:' + (oli.Atlassian_Partner_Discount__c != null ? oli.Atlassian_Partner_Discount__c.format() : '') +
                ', Entitlement Number: ' + oli.Entitlement_Number__c);
            i++;
        }

        return opptyProductsToInsert;
    }

    /**
     * Merge equal products into one OpportunityLineItem, but keep entitlement numbers separated (if needed)
     *
     * @param items - List of OpportunityLineItems
     * @param log - LogData object to store logs
     *
     * @return List of OpportunityLineItems with merged products
     */
    private static List<OpportunityLineItem> mergeEqualProducts(List<OpportunityLineItem> items, OpportunityProductMapper.LogData log) {
        Map<String, OpportunityLineItem> itemsByProduct = new Map<String, OpportunityLineItem>();
        for (OpportunityLineItem item : items) {
            String key = item.PpcLineItemId__c + '-' + item.License_Start_date__c + '-' + item.License_end_date__c;
            System.debug('*** USING KEY = ' + key);
            if (itemsByProduct.containsKey(key)) {
                OpportunityLineItem existingItem = itemsByProduct.get(key);

                System.debug(existingItem.Editable_Unit_List_Price_in_USD__c + ' + ' + item.Editable_Unit_List_Price_in_USD__c);
                System.debug(existingItem.Editable_Cost_Price_in_Dollars__c + ' + ' + item.Editable_Cost_Price_in_Dollars__c);

                existingItem.Editable_Unit_List_Price_in_USD__c += item.Editable_Unit_List_Price_in_USD__c;
                existingItem.Editable_Cost_Price_in_Dollars__c += item.Editable_Cost_Price_in_Dollars__c;

                Double existingPartnerDiscount = (existingItem.Atlassian_Partner_Discount__c == null) ? 0.0 : existingItem.Atlassian_Partner_Discount__c;
                Double itemPartnerDiscount = (item.Atlassian_Partner_Discount__c == null) ? 0.0 : item.Atlassian_Partner_Discount__c;
                existingPartnerDiscount += itemPartnerDiscount;
                existingItem.Atlassian_Partner_Discount__c = existingPartnerDiscount;

                Double existingPriceAdjustment = (existingItem.Atlassian_Price_Adjustment__c == null) ? 0.0 : existingItem.Atlassian_Price_Adjustment__c;
                Double itemPriceAdjustment = (item.Atlassian_Price_Adjustment__c == null) ? 0.0 : item.Atlassian_Price_Adjustment__c;
                existingPriceAdjustment += itemPriceAdjustment;
                existingItem.Atlassian_Price_Adjustment__c = existingPriceAdjustment;

                if (!(item.Editable_Unit_List_Price_in_USD__c < 0 || item.Editable_Cost_Price_in_Dollars__c < 0)) {
                    existingItem.User_Count__c += item.User_Count__c;
                }
            } else {
                // Make sure credits user count does not add up to the total.
                if ((item.Editable_Unit_List_Price_in_USD__c < 0 || item.Editable_Cost_Price_in_Dollars__c < 0)) {
                    item.User_Count__c = 0;
                }

                itemsByProduct.put(key, item);
            }
        }

        if (itemsByProduct.size() != items.size()) {
            log.successLog.add('Merged ' + (items.size() - itemsByProduct.size()) + ' duplicate line items from originally ' + items.size() + ' items to ' + itemsByProduct.size() + ' items');
        }

        return itemsByProduct.values();
    }

    /**
     * Merge date ranges for the same entitlement number
     *
     * @param items - List of OpportunityLineItems
     * @param log - LogData object to store logs
     *
     * @return List of OpportunityLineItems with merged date ranges
     */
    private static List<OpportunityLineItem> mergeDateRanges(List<OpportunityLineItem> items, OpportunityProductMapper.LogData log) {
        Map<String, OpportunityLineItem> itemsByEntitlement = new Map<String, OpportunityLineItem>();
        for (OpportunityLineItem item : items) {
            String key = item.Entitlement_Number__c;
            System.debug('*** USING KEY = ' + key);
            if (itemsByEntitlement.containsKey(key)) {
                OpportunityLineItem existingItem = itemsByEntitlement.get(key);

                System.debug(existingItem.Editable_Unit_List_Price_in_USD__c + ' + ' + item.Editable_Unit_List_Price_in_USD__c);
                System.debug(existingItem.Editable_Cost_Price_in_Dollars__c + ' + ' + item.Editable_Cost_Price_in_Dollars__c);

                existingItem.Editable_Unit_List_Price_in_USD__c += item.Editable_Unit_List_Price_in_USD__c;
                existingItem.Editable_Cost_Price_in_Dollars__c += item.Editable_Cost_Price_in_Dollars__c;

                Double existingPartnerDiscount = (existingItem.Atlassian_Partner_Discount__c == null) ? 0.0 : existingItem.Atlassian_Partner_Discount__c;
                Double itemPartnerDiscount = (item.Atlassian_Partner_Discount__c == null) ? 0.0 : item.Atlassian_Partner_Discount__c;
                existingPartnerDiscount += itemPartnerDiscount;
                existingItem.Atlassian_Partner_Discount__c = existingPartnerDiscount;

                Double existingPriceAdjustment = (existingItem.Atlassian_Price_Adjustment__c == null) ? 0.0 : existingItem.Atlassian_Price_Adjustment__c;
                Double itemPriceAdjustment = (item.Atlassian_Price_Adjustment__c == null) ? 0.0 : item.Atlassian_Price_Adjustment__c;
                existingPriceAdjustment += itemPriceAdjustment;
                existingItem.Atlassian_Price_Adjustment__c = existingPriceAdjustment;

                Date firstDate = (item.License_Start_date__c < existingItem.License_Start_date__c) ? item.License_Start_date__c : existingItem.License_Start_date__c;
                Date lastDate = (item.License_end_date__c > existingItem.License_end_date__c) ? item.License_end_date__c : existingItem.License_end_date__c;
                existingItem.License_Start_date__c = firstDate;
                existingItem.License_end_date__c = lastDate;
            } else {
                itemsByEntitlement.put(key, item);
            }
        }

        if (itemsByEntitlement.size() != items.size()) {
            log.successLog.add('Merged ' + (items.size() - itemsByEntitlement.size()) + ' duplicate line items from originally ' + items.size() + ' items to ' + itemsByEntitlement.size() + ' items');
        }

        return itemsByEntitlement.values();
    }

    /**
     * Get PricebookEntry objects mapped by Product2 Id
     *
     * @param productIds - Set of Product2 Ids
     * @param opp - Opportunity
     *
     * @return Map of PricebookEntry objects mapped by Product2 Id
     */
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

    /**
     * Map Quote line to Opportunity product
     *
     * @param pbEntry - Pricebook Entry
     * @param oppId - Opportunity Id
     * @param quoteLine - Invoice line
     * @param conversionFactor - Currency conversion factor
     *
     * @return OpportunityLineItem
     */
    public OpportunityLineItem mapQuoteLineToOpportunityLineItem(PricebookEntry pbEntry, Id oppId, PortalCommerceApiQuotes.BillLineItem quoteLine, Double conversionFactor) {
        OpportunityLineItem oli = new OpportunityLineItem();

        System.debug(JSON.serializePretty(quoteLine));

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
        oli.SEN__c = quoteLine.entSlug;
        oli.Entitlement_Number__c = quoteLine.entSlug;
        oli.Editable_Cost_Price_in_Dollars__c = (quoteLine.amountExcludingTax == null) ? 0 : quoteLine.amountExcludingTax / 100.0;
        oli.User_Count__c = quoteLine.quantity;
        oli.Atlassian_Price_Adjustment__c = quoteLine.adjustmentAmount;
//        oli.Atlassian_Upgrade_Credit__c = quoteLine.upgradeCredit;
        oli.Atlassian_Partner_Discount__c = quoteLine.discountAmount;
//        oli.Atlassian_Loyalty_Discount__c = quoteLine.loyaltyDiscountTotal;
        oli.QuoteOriginalProduct__c = quoteLine.description;
        oli.Quantity = 1;
        oli.Editable_Unit_List_Price_in_USD__c = (quoteLine.subTotal == null) ? 0 : quoteLine.subTotal / 100.0;
        oli.Renewal__c = SALE_TYPE_MAPPING.get(quoteLine.salesType) == null
            ? SALE_TYPE_MAPPING.get('RENEWAL')
            : SALE_TYPE_MAPPING.get(quoteLine.salesType);
        oli.PpcLineItemId__c = quoteLine.quoteLineId;
        oli.AtlassianOfferingKey__c = quoteLine.offeringId;
        oli.AtlassianOffering__r = new AtlassianOffering__c(AtlassianId__c = quoteLine.offeringId);

        return oli;
    }

    public OpportunityLineItem mapInvoiceLineToOpportunityLineItem(PricebookEntry pbEntry, Id oppId, PortalCommerceApiInvoices.InvoiceItem invoiceLine, Double conversionFactor) {
        OpportunityLineItem oli = new OpportunityLineItem();

        System.debug(JSON.serializePretty(invoiceLine));

        /*
            item.discountAmount = (item.margins && item.margins.length > 0)
                ? item.margins.reduce((sum, margin) => sum + margin.amount, 0)
                : 0;
            item.adjustmentAmount = (item.adjustments && item.adjustments.length > 0)
                ? item.adjustments.reduce((sum, ajdjustment) => sum + ajdjustment.amount, 0)
                : 0;

         */

        if (invoiceLine.adjustments != null && invoiceLine.adjustments.size() > 0) {
            System.debug('++ Adjustments: ' + invoiceLine.adjustments);
            invoiceLine.adjustmentAmount = 0;
            for (PortalCommerceApiInvoices.AdjustmentType adjustment : invoiceLine.adjustments) {
                invoiceLine.adjustmentAmount += adjustment.amount;
                System.debug('  -- Adjustment: ' + adjustment.amount);
            }
        }

        if (invoiceLine.margins != null && invoiceLine.margins.size() > 0) {
            System.debug('++ Margins: ' + invoiceLine.margins);
            invoiceLine.discountAmount = 0;
            for (PortalCommerceApiInvoices.MarginType margin : invoiceLine.margins) {
                invoiceLine.discountAmount += margin.amount;
                System.debug('  -- Margin: ' + margin.amount);
            }
        }

        oli.PricebookEntryId = pbEntry.Id;
        oli.Product2Id = pbEntry.Product2Id;
        oli.OpportunityId = oppId;
        Long startsAt = invoiceLine?.period?.startAt;
        Long endsAt = invoiceLine?.period?.endAt;
        oli.License_Start_date__c = (startsAt != null) ? Datetime.newInstance(startsAt).date() : Date.today();
        oli.License_end_date__c = (endsAt != null) ? Datetime.newInstance(endsAt).date() : null;
        oli.Additional_Info__c = invoiceLine.description;
        oli.Cloud_Site_Name__c = invoiceLine.entName;
        oli.SEN__c = invoiceLine.entitlementNumber;
        oli.Entitlement_Number__c = invoiceLine.entitlementNumber;
        oli.Editable_Cost_Price_in_Dollars__c = ((invoiceLine.total == null) ? 0 : invoiceLine.total) - ((invoiceLine.tax == null) ? 0 : invoiceLine.tax);
        oli.User_Count__c = invoiceLine.quantity;
        oli.Atlassian_Price_Adjustment__c = invoiceLine.adjustmentAmount;
        oli.Atlassian_Partner_Discount__c = invoiceLine.discountAmount;
        oli.QuoteOriginalProduct__c = invoiceLine.description;
        oli.Quantity = 1;
        oli.Editable_Unit_List_Price_in_USD__c = (invoiceLine.subTotal == null) ? 0 : invoiceLine.subTotal;
        oli.Renewal__c = SALE_TYPE_MAPPING.get(invoiceLine.salesType) == null
            ? SALE_TYPE_MAPPING.get('RENEWAL')
            : SALE_TYPE_MAPPING.get(invoiceLine.salesType);
        oli.PpcLineItemId__c = invoiceLine.orderItemId;
        oli.AtlassianOfferingKey__c = invoiceLine.offeringKey;
        oli.AtlassianOffering__r = new AtlassianOffering__c(AtlassianId__c = invoiceLine.offeringKey);

        return oli;
    }
}