/**
 * Created by peterfriberg on 2024-10-15.
 */

public without sharing class PpcInvoiceConverter {

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

            // Replaced:
            //   insert oppProducts;
            // with a queueable to avoid hitting the DML row limit and flow limits
            enqueueProductInsertion(opp, oppProducts);

            log.successLog.add(oppProducts.size() + ' Opportunity Products added successfully');
            try {
                updateOpportunity(opp, invoiceData, log);
                log.successLog.add('Opportunity updated successfully');
            } catch (Exception ex) {
                String error = 'ERROR: Failed updating Opportunity: ' + ex.getMessage() + ex.getStackTraceString();
                log.errorLog.add(error);
                System.debug('ERROR: ' + error);
                try {
                    delete oppProducts;
                    String action = 'INFORMATION: Opportunity Line Items that were added, has now been removed!';
                    log.errorLog.add(action);
                }
                catch (Exception ex2) {
                    String message = 'ERROR: Failed removing Opportunity Line Items that were added!';
                    log.errorLog.add(message);
                }
            }
        }

        return log;
    }

    @TestVisible
    private static void enqueueProductInsertion(Opportunity opp, List<OpportunityLineItem> oppProducts) {
        System.enqueueJob(
            new ProcessOpportunityLinesQueueable(
                new OpportunityData(opp.Id, opp.StageName, oppProducts)));
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
        Opportunity updatedOpp = new Opportunity(
            Id = opp.Id,
            Atlassian_AT_Quote_ref__c = invoiceData.invoiceNumber,
            Atlassian_AT_Quote_amount__c = invoiceData.subTotal,
            AT_quote_expiry__c = invoiceData.dueAt != null ? Datetime.newInstance(invoiceData.dueAt).date() : null,
            PpcQuoteImportResult__c = (String.join(log.productLog, '\n').left(16000) + '\n' + String.join(log.pbeLog, '\n').left(16000)).left(32766)
        );
        update updatedOpp;
    }
}