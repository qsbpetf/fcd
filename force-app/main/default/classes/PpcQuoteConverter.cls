/**
 * Created by peterfriberg on 2024-09-03.
 */

public with sharing class PpcQuoteConverter {

    @AuraEnabled
    public static OpportunityProductMapper.LogData convertQuote(String jsonText, String oppId, Boolean createProducts, Boolean mergeLineItems) {
        Opportunity opp = PortalQuoteConverter.getOpportunity(oppId);
        Double conversionFactor = PortalQuoteConverter.getLatestCurrencyConversionFactor(opp.CurrencyIsoCode);
        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        PortalCommerceApiQuotes.QuoteInfo quoteData = (PortalCommerceApiQuotes.QuoteInfo) JSON.deserialize(jsonText, PortalCommerceApiQuotes.QuoteInfo.class);
        System.debug('QUOTE IN JSON:\n' + JSON.serializePretty(quoteData));

        List<OpportunityLineItem> oppProducts = mapProducts(quoteData, opp, conversionFactor, log, mergeLineItems);

        System.debug('INSERTING PRODUCTS: ' + createProducts);
        for (OpportunityLineItem oppProduct : oppProducts) {
            System.debug('   PRODUCT: ' + JSON.serializePretty(oppProduct));
        }
        if (createProducts) {
            insert oppProducts;
            log.successLog.add(oppProducts.size() + ' Opportunity Products added successfully');
            try {
                updateOpportunity(opp, quoteData, log);
                log.successLog.add('Opportunity updated successfully');
            } catch (Exception ex) {
                String error = 'ERROR: Failed updating Opportunity/Contact: ' + ex.getMessage() + ex.getStackTraceString();
                log.errorLog.add(error);
                System.debug(error);
            }
        }

        return log;
    }

    @TestVisible
    private static List<OpportunityLineItem> mapProducts(
        PortalCommerceApiQuotes.QuoteInfo quoteData,
        Opportunity opp, Double conversionFactor,
        OpportunityProductMapper.LogData log,
        Boolean mergeLineItems)
    {
        PpcOpportunityProductMapper oppMapper = PpcOpportunityProductMapper.getInstance();
        List<OpportunityLineItem> oppProducts = oppMapper.mapProducts(quoteData, opp, conversionFactor, log, mergeLineItems);

        return oppProducts;
    }

    @TestVisible
    private static void updateOpportunity(Opportunity opp, PortalCommerceApiQuotes.QuoteInfo quoteData, OpportunityProductMapper.LogData log) {
        opp.Atlassian_AT_Quote_ref__c = quoteData.quoteNumber;
        opp.Atlassian_AT_Quote_amount__c = quoteData.upcomingBills.subTotal;
        opp.AT_quote_expiry__c = quoteData.expiresAt != null ? Datetime.newInstance(quoteData.expiresAt).date() : null;
        opp.PpcQuoteImportResult__c = (String.join(log.productLog, '\n') + '\n' + String.join(log.pbeLog, '\n')).left(32766);
        update opp;
    }
}