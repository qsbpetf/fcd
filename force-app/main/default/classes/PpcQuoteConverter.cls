/**
 * Created by peterfriberg on 2024-09-03.
 */

public without sharing class PpcQuoteConverter {

    @AuraEnabled
    public static OpportunityProductMapper.LogData convertQuote(String jsonText, String oppId, Boolean createProducts, Boolean mergeLineItems) {
        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        Opportunity opp = PortalQuoteConverter.getOpportunity(oppId);
        Double conversionFactor = PortalQuoteConverter.getLatestCurrencyConversionFactor(opp.CurrencyIsoCode);
        PortalCommerceApiQuotes.QuoteInfo quoteData = (PortalCommerceApiQuotes.QuoteInfo) JSON.deserialize(jsonText, PortalCommerceApiQuotes.QuoteInfo.class);
        System.debug('QUOTE IN JSON:\n' + JSON.serializePretty(quoteData));

        List<OpportunityLineItem> oppProducts = mapProducts(quoteData, opp, conversionFactor, log, mergeLineItems);

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
                updateOpportunity(opp, quoteData, log);
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
        String jobId = System.enqueueJob(new ProcessOpportunityLinesQueueable(new OpportunityData(opp.Id, opp.StageName, oppProducts)));
        System.debug('### Next batch of opportunity line items enqueued. Job ID: ' + jobId);
    }

    @TestVisible
    private static List<OpportunityLineItem> mapProducts(
        PortalCommerceApiQuotes.QuoteInfo quoteData,
        Opportunity opp,
        Double conversionFactor,
        OpportunityProductMapper.LogData log,
        Boolean mergeLineItems)
    {
        PpcOpportunityProductMapper oppMapper = PpcOpportunityProductMapper.getInstance();
        List<OpportunityLineItem> oppProducts = oppMapper.mapProducts(quoteData, opp, conversionFactor, log, mergeLineItems);

        return oppProducts;
    }

    @TestVisible
    private static void updateOpportunity(Opportunity opp, PortalCommerceApiQuotes.QuoteInfo quoteData, OpportunityProductMapper.LogData log) {
        Opportunity updatedOpp = new Opportunity(
            Id = opp.Id,
            Atlassian_AT_Quote_ref__c = quoteData.quoteNumber,
            Atlassian_AT_Quote_amount__c = quoteData.upcomingBills.subTotal / 100.0,
            AT_quote_expiry__c = quoteData.expiresAt != null ? Datetime.newInstance(quoteData.expiresAt).date() : null,
            PpcQuoteImportResult__c = (String.join(log.productLog, '\n').left(16000) + '\n' + String.join(log.pbeLog, '\n').left(16000)).left(32766)
        );
        update updatedOpp;
    }
}