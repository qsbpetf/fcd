public with sharing class PortalQuoteConverter {

    @AuraEnabled
    public static OpportunityProductMapper.LogData convertQuote(String jsonText, String oppId, Boolean createProducts) {
        PortalJsonParser.OrderInformation orderInfo = parseJson(jsonText);
        Opportunity opp = getOpportunity(oppId);
        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        Double conversionFactor = getLatestCurrencyConversionFactor(opp.CurrencyIsoCode);
        List<OpportunityLineItem> oppProducts = mapProducts(orderInfo, opp, conversionFactor, log);
        System.debug('INSERTING PRODUCTS: ' + createProducts);
        for (OpportunityLineItem oppProduct : oppProducts) {
            System.debug('   PRODUCT: ' + JSON.serializePretty(oppProduct));
        }
        if (createProducts) {
            insert oppProducts;
        }
        updateOpportunity(opp, orderInfo, log);

        return log;
    }

    @AuraEnabled
    public static String getJsonFile(String contentBodyId, String contentVersionId, String documentId, String oppId) {
        String versionDataString = '';

        // Getting the Content Data
        ContentVersion cv = [
            SELECT Id, Title, VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        versionDataString = cv.VersionData.toString();

        // Deleting the ContentDocument
        ContentDocument cd = [
            SELECT Id
            FROM ContentDocument
            WHERE Id = :documentId
            LIMIT 1
        ];
        delete cd;

        return versionDataString;
    }

    private static PortalJsonParser.OrderInformation parseJson(String jsonText) {
        PortalJsonParser parser = PortalJsonParser.getInstance();
        PortalJsonParser.OrderInformation orderInfo = parser.parseJson(jsonText);

        return orderInfo;
    }

    private static Double getLatestCurrencyConversionFactor(String currencyIsoCode) {
        List<Buying_Exchange_Rate__c> currencyList = [
            SELECT
                Exchange_Rate_from_USD_to_EUR__c,
                Exchange_Rate_from_USD_to_GBP__c,
                Start_Date__c
            FROM Buying_Exchange_Rate__c
            ORDER BY Start_Date__c DESC
            LIMIT 1
        ];

        if (currencyList.isEmpty()) {
            return 1;
        }
        Buying_Exchange_Rate__c conversionRate = currencyList[0];
        System.debug('Currency: ' + currencyIsoCode + ' Rate: ' + conversionRate);

        switch on currencyIsoCode {
            when 'EUR' {
                return conversionRate.Exchange_Rate_from_USD_to_EUR__c;
            }
            when 'GBP' {
                return conversionRate.Exchange_Rate_from_USD_to_GBP__c;
            }
            when else {
                return 1;
            }
        }
    }

    private static List<OpportunityLineItem> mapProducts(PortalJsonParser.OrderInformation orderInfo, Opportunity opp, Double conversionFactor, OpportunityProductMapper.LogData log) {
        OpportunityProductMapper opMapper = OpportunityProductMapper.getInstance();
        List<OpportunityLineItem> oppProducts = opMapper.mapProducts(orderInfo, opp, conversionFactor, log);

        return oppProducts;
    }

    private static Opportunity getOpportunity(String oppId) {
        Opportunity opp = [
            SELECT Id,
                Pricebook2Id,
                Pricebook2.Name,
                CurrencyIsoCode,
                Atlassian_AT_Quote_ref__c,
                Technical_Contact_email__c,
                Atlassian_AT_Quote_amount__c,
                AT_quote_expiry__c,
                QuoteImportResult__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        System.debug('OPPINFO: ' + opp + ' Pricebook=' + opp.Pricebook2.Name);
        return opp;
    }

    private static void updateOpportunity(Opportunity opp, PortalJsonParser.OrderInformation orderInfo, OpportunityProductMapper.LogData log) {
        opp.Atlassian_AT_Quote_ref__c = orderInfo.orderNumber;
        // opp.Technical_Contact_email__c = orderInfo.technicalContactEmail; // cannot map to formula field, create new email adress field? (see slide 7 )
        opp.Atlassian_AT_Quote_amount__c = orderInfo.totalExTax;
        opp.AT_quote_expiry__c = orderInfo.dueDate;
        opp.QuoteImportResult__c = String.join(log.productLog, '\n') + '\n' + String.join(log.pbeLog, '\n');
        update opp;
    }
}