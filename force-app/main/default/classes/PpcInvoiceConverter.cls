/**
 * Created by peterfriberg on 2024-10-15.
 */

public with sharing class PpcInvoiceConverter {

    @AuraEnabled
    public static OpportunityProductMapper.LogData convertInvoice(String jsonText, String oppId, Boolean createProducts, Boolean mergeLineItems) {
        Opportunity opp = PortalQuoteConverter.getOpportunity(oppId);
        Double conversionFactor = PortalQuoteConverter.getLatestCurrencyConversionFactor(opp.CurrencyIsoCode);
        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        PortalCommerceApiInvoices.InvoiceInfo invoiceData = (PortalCommerceApiInvoices.InvoiceInfo) JSON.deserialize(jsonText, PortalCommerceApiInvoices.InvoiceInfo.class);
        System.debug('INVOICE IN JSON:\n' + JSON.serializePretty(invoiceData));

        List<OpportunityLineItem> oppProducts = mapProducts(invoiceData, opp, conversionFactor, log, mergeLineItems);

        System.debug('INSERTING PRODUCTS: ' + createProducts);
        for (OpportunityLineItem oppProduct : oppProducts) {
            System.debug('   PRODUCT: ' + JSON.serializePretty(oppProduct));
        }
        if (createProducts) {
            insert oppProducts;
            log.successLog.add(oppProducts.size() + ' Opportunity Products added successfully');
            try {
                updateOpportunity(opp, invoiceData, log);
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
        PortalCommerceApiInvoices.InvoiceInfo invoiceData,
        Opportunity opp,
        Double conversionFactor,
        OpportunityProductMapper.LogData log,
        Boolean mergeLineItems)
    {
        PpcOpportunityProductMapper oppMapper = PpcOpportunityProductMapper.getInstance();
        List<OpportunityLineItem> oppProducts = oppMapper.mapProducts(invoiceData, opp, conversionFactor, log, mergeLineItems);

        return oppProducts;
    }

    @TestVisible
    private static void updateOpportunity(Opportunity opp, PortalCommerceApiInvoices.InvoiceInfo invoiceData, OpportunityProductMapper.LogData log) {
        opp.Atlassian_AT_Quote_ref__c = invoiceData.invoiceNumber;
        opp.Atlassian_AT_Quote_amount__c = invoiceData.subTotal;
        opp.AT_quote_expiry__c = invoiceData.dueAt != null ? Datetime.newInstance(invoiceData.dueAt).date() : null;
        opp.PpcQuoteImportResult__c = (String.join(log.productLog, '\n') + '\n' + String.join(log.pbeLog, '\n')).left(32766);
        update opp;
    }
}