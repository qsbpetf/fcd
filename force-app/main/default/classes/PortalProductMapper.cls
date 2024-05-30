/**
 * Created by peterfriberg on 2024-05-30.
 */

public with sharing class PortalProductMapper {

    private static PortalProductMapper instance;
    private final Map<String, String> productNameMapping;
    private final Map<String, Product2> productByNameMapping;

    public static PortalProductMapper getInstance() {
        if (instance == null) {
            instance = new PortalProductMapper();
        }
        return instance;
    }

    public PortalProductMapper() {
        this.productNameMapping = prepareProductNameMapping();
        this.productByNameMapping = prepareProductByNameMapping();
    }

    private Map<String, String> prepareProductNameMapping() {
        Map<String, String> result = new Map<String, String>();
        Map<String, PortalProductToSalesforceMapping__mdt> rows = PortalProductToSalesforceMapping__mdt.getAll();
        for (PortalProductToSalesforceMapping__mdt row : rows.values()) {
            String prodName = row.ProductName__c;
            String platform = row.Platform__c;
            String edition = row.Edition__c;
            String key = prodName + ':' + platform + ':' + edition;
            // String salesforceProduct = row.SalesforceProductName__c;
            // System.debug(key + ' => ' + salesforceProduct);
            result.put(key, row.SalesforceProductName__c);
        }
        return result;
    }

    private Map<String, Product2> prepareProductByNameMapping() {
        Map<String, Product2> result = new Map<String, Product2>();
        List<Product2> salesforceProducts = new List<Product2>([
            SELECT Id, Name
            FROM Product2
            WHERE Name IN :productNameMapping.values()
        ]);
        for (Product2 product : salesforceProducts) {
            result.put(product.Name, product);
        }
        return result;
    }

    public MappingResult mapProduct(String productName, String platform, String edition) {
        MappingResult result = new MappingResult();

        // Full key is productName:platform:edition. Full search is done first.
        String fullKey = productName + ':' + platform + ':' + edition;
        System.debug('Searching for fullKey ' + fullKey);
        String salesforceProductName = productNameMapping.get(fullKey);
        if (salesforceProductName != null) {
            Product2 product = productByNameMapping.get(salesforceProductName);
            result.product = product;
            if (product == null) {
                result.error = 'No Salesforce product id found for ' + salesforceProductName + ' in ' + fullKey;
            }
            return result;
        }

        // If full key search failed, try to find a product without product name.
        String key = 'null:' + platform + ':' + edition;
        System.debug('Searching for key ' + key);
        salesforceProductName = productNameMapping.get(key);
        if (salesforceProductName != null) {
            Product2 product = productByNameMapping.get(salesforceProductName);
            result.product = product;
            if (product == null) {
                result.error = 'No Salesforce product id found for ' + salesforceProductName + ' in ' + key;
            } else {
                result.error = 'No specific product found for ' + productName + '. Using ' + salesforceProductName + ' in ' + key;
            }
            return result;
        }

        // If no product found, return default.
        String defaultKey = 'null:null:null';
        System.debug('Searching for defaultKey ' + defaultKey);
        salesforceProductName = productNameMapping.get(defaultKey);
        if (salesforceProductName != null) {
            Product2 product = productByNameMapping.get(salesforceProductName);
            result.product = product;
            if (product == null) {
                result.error = 'No Salesforce product id found for ' + salesforceProductName + ' in ' + key;
            }
            return result;
        }

        result.error = 'No default Salesforce product id found';
        return result;
    }

    public class MappingResult {
        public Product2 product;
        public String error;
    }
}