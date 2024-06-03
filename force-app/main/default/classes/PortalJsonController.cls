/**
 * Created by peterfriberg on 2024-05-31.
 */

public with sharing class PortalJsonController {

    @AuraEnabled
    public static PortalJsonParser.OrderInformation parseJson(String jsonText) {
        PortalJsonParser parser = PortalJsonParser.getInstance();
        PortalJsonParser.OrderInformation orderInfo = parser.parseJson(jsonText);

        return orderInfo;
    }

    @AuraEnabled
    public static List<PortalProductMapper.MappingResult> parseJsonAndMapProduct(String jsonText) {
        PortalJsonParser parser = PortalJsonParser.getInstance();
        PortalJsonParser.OrderInformation orderInfo = parser.parseJson(jsonText);

        Opportunity oppty = new Opportunity();
        oppty.Name = orderInfo.orderNumber;
        oppty.CloseDate = orderInfo.dueDate;
        oppty.StageName = 'Prospecting';
        oppty.Amount = orderInfo.totalExTax;
        oppty.Type = 'New Business';

        List<PortalProductMapper.MappingResult> results = new List<PortalProductMapper.MappingResult>();
        PortalProductMapper mapper = PortalProductMapper.getInstance();

        for (PortalJsonParser.OrderLine orderLine : orderInfo.orderItems) {
            PortalProductMapper.MappingResult result = mapper.mapProduct(orderLine.productName, orderLine.platform, orderLine.edition);
            results.add(result);
        }

        return results;
    }
}