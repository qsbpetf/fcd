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
            updateOpportunity(opp, orderInfo, log);
        }

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

    @TestVisible
    private static PortalJsonParser.OrderInformation parseJson(String jsonText) {
        PortalJsonParser parser = PortalJsonParser.getInstance();
        PortalJsonParser.OrderInformation orderInfo = parser.parseJson(jsonText);

        return orderInfo;
    }

    @TestVisible
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

    @TestVisible
    private static List<OpportunityLineItem> mapProducts(PortalJsonParser.OrderInformation orderInfo, Opportunity opp, Double conversionFactor, OpportunityProductMapper.LogData log) {
        OpportunityProductMapper oppMapper = OpportunityProductMapper.getInstance();
        List<OpportunityLineItem> oppProducts = oppMapper.mapProducts(orderInfo, opp, conversionFactor, log);

        return oppProducts;
    }

    @TestVisible
    private static Opportunity getOpportunity(String oppId) {
        Opportunity opp = [
            SELECT
                Id,
                AccountId,
                Pricebook2Id,
                Pricebook2.Name,
                CurrencyIsoCode,
                Atlassian_AT_Quote_ref__c,
                Technical_Contact_email__c,
                Atlassian_AT_Quote_amount__c,
                Atlassian_AT_Quote_Tech_Contact__c,
                AT_quote_expiry__c,
                QuoteImportResult__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        System.debug('OPPINFO: ' + opp + ' Pricebook=' + opp.Pricebook2.Name);
        return opp;
    }

    @TestVisible
    private static void updateOpportunity(Opportunity opp, PortalJsonParser.OrderInformation orderInfo, OpportunityProductMapper.LogData log) {
        opp.Atlassian_AT_Quote_ref__c = orderInfo.orderNumber;
        // opp.Technical_Contact_email__c = orderInfo.technicalContactEmail; // cannot map to formula field, create new email adress field? (see slide 7 )
        opp.Atlassian_AT_Quote_amount__c = orderInfo.totalExTax;
        opp.AT_quote_expiry__c = orderInfo.dueDate;
        opp.QuoteImportResult__c = String.join(log.productLog, '\n') + '\n' + String.join(log.pbeLog, '\n');

        if (opp.Atlassian_AT_Quote_Tech_Contact__c == null) {
            Contact con = findOrCreateContact(opp, orderInfo.technicalContact);
            opp.Atlassian_AT_Quote_Tech_Contact__c = con.Id;
        }

        update opp;
    }

    @TestVisible
    private static Contact findOrCreateContact(Opportunity opp, PortalJsonParser.TechnicalContactDetails techCon) {
        Contact con;

        List<Contact> conList = new List<Contact>([
            SELECT Id
            FROM Contact
            WHERE Email = :techCon.email AND AccountId = :opp.AccountId
            LIMIT 1
        ]);

        if (conList.isEmpty()) {
            con = new Contact();
            con.Email = techCon.email;
            con.FirstName = techCon.firstName;
            con.LastName = techCon.lastName;
            con.Phone = techCon.phone;
            con.AccountId = opp.AccountId;
            con.MailingStreet = techCon?.address?.address1;
            con.MailingCity = techCon?.address?.city;
            con.MailingState = techCon?.address?.state;
            con.MailingPostalCode = techCon?.address?.postalCode;
            con.MailingCountry = techCon?.address?.country;

            try {
                System.debug('Creating contact with state: ' + con.MailingState + ': ' + con);
                insert con;
            } catch (System.DmlException ex) {
                if (ex.getMessage().containsIgnoreCase('Please select a state from the list of valid states.')) {
                    con.MailingState = null;
                    System.debug('Creating contact:  with removed state: ' + con.MailingState + ': ' + con);
                    insert con;
                } else {
                    throw ex;
                }
            }
        } else {
            con = conList[0];
        }

        return con;
    }
}