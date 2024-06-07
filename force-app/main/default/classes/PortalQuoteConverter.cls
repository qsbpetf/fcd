public with sharing class PortalQuoteConverter {

    @AuraEnabled
    public static void convertQuote(String jsonFile, String oppId){

        // Parse incoming JSON
        PortalJsonParser.OrderInformation orderInfo = parseJson(jsonFile);

        //Map Portal Product to SF Products and Opportunity Product
        List<OpportunityLineItem> oppProducts = mapProduct(orderInfo, oppId);

        //Insert Opportunity Products here?
        //return status?

    }

    private PortalJsonParser.OrderInformation parseJson(String jsonText) {
        PortalJsonParser parser = PortalJsonParser.getInstance();
        PortalJsonParser.OrderInformation orderInfo = parser.parseJson(jsonText);

        return orderInfo;
    }

    private List<OpportunityLineItem> mapProduct(PortalJsonParser.OrderInformation orderInfo, String oppId){
        
        PortalProductMapper portalProductMapper = PortalProductMapper.getInstance();
        OpportunityProductMapper oppProductMapper = OpportunityProductMapper.getInstance();
        List<OpportunityLineItem> result = new List<OpportunityLineitem>();

        for (PortalJsonParser.OrderLine orderLine : orderInfo.orderItems) {
            //map to product2
            PortalProductMapper.MappingResult mapResult = portalProductMapper.mapProduct(orderLine.productName, orderLine.platform, orderLine.edition);
            if (mapResult.found) {
                //map to oppProduct
                OpportunityLineItem oppProduct = oppProductMapper.mapProducts(mapResult.product, oppId, orderLine);
                result.add(oppProduct);
            }
        }

        return result; // or insert opls here and return status?
    }
}