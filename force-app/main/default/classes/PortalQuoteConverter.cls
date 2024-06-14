public with sharing class PortalQuoteConverter {

    @AuraEnabled
    public static void convertQuote(String jsonFile, String oppId){

        // Parse incoming JSON
        PortalJsonParser.OrderInformation orderInfo = parseJson(jsonFile);

        //Map Portal Product to SF Products and Opportunity Product
        List<OpportunityLineItem> oppProducts = mapProduct(orderInfo, oppId);

        //Update Opportunity with PortalQuoteId
        Opportunity oppty = updateOpportunity(oppId, orderInfo);

        //update oppty and insert opp line items in another layer? 

        //return

    }

    private static PortalJsonParser.OrderInformation parseJson(String jsonText) {
        PortalJsonParser parser = PortalJsonParser.getInstance();
        PortalJsonParser.OrderInformation orderInfo = parser.parseJson(jsonText);

        return orderInfo;
    }

    private static List<OpportunityLineItem> mapProduct(PortalJsonParser.OrderInformation orderInfo, String oppId){
        
        PortalProductMapper portalProductMapper = PortalProductMapper.getInstance();
        OpportunityProductMapper oppProductMapper = OpportunityProductMapper.getInstance();

        List<OpportunityLineItem> result = new List<OpportunityLineitem>();
        List<Product2> mappedProducts = new List<Product2>();
        List<PortalJsonParser.OrderLine> orderLines = new List<PortalJsonParser.OrderLine>();

        for (PortalJsonParser.OrderLine orderLine : orderInfo.orderItems) {
            //map to product2
            PortalProductMapper.MappingResult mapResult = portalProductMapper.mapProduct(orderLine.productName, orderLine.platform, orderLine.edition);
            if (mapResult.found) {
                mappedProducts.add(mapResult.product);
                orderLines.add(orderLine);
            }
            //if not found, return mapResult.info to UI?
        }

        //map to oppProduct
        OpportunityLineItem oppProduct = oppProductMapper.mapProducts(mappedProducts, oppId, orderLines);
        result.add(oppProduct);

        return result;
    }

    private static Opportunity updateOpportunity(String oppId, PortalJsonParser.OrderInformation orderInfo ){

        Opportunity oppty = [SELECT Id, Atlassian_AT_Quote_ref__c, Technical_Contact_email__c,	Atlassian_AT_Quote_amount__c, AT_quote_expiry__c
                            FROM Opportunity
                            WHERE Id = :oppId
                            LIMIT 1];

        oppty.Atlassian_AT_Quote_ref__c = orderInfo.orderNumber;
        //oppty.Technical_Contact_email__c = orderInfo.technicalContactEmail; // cannot map to formula field, create new email adress field? (see slide 7 )
        oppty.Atlassian_AT_Quote_amount__c = orderInfo.totalExTax;
        oppty.AT_quote_expiry__c = orderInfo.dueDate;

        return oppty;
    }
}