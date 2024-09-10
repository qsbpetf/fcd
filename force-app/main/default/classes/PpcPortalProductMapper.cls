/**
 * Created by peterfriberg on 2024-09-03.
 */

public with sharing class PpcPortalProductMapper {

    private static PpcPortalProductMapper instance;
    private final Set<String> partnerProducts = new Set<String>();    // Set of all unique partner products
    private final Set<String> salesforceProducts = new Set<String>(); // Set of all unique Salesforce products
    private final Map<String, Product2> productByNameMapping;         // Mapping from Salesforce Product Name to Product2 records
//    private final Product2 defaultCloudProduct;
//    private final Product2 defaultDatacenterProduct;
    private final List<ProductInfo> productInfos = new List<ProductInfo>();

    public static PpcPortalProductMapper getInstance() {
        if (instance == null) {
            instance = new PpcPortalProductMapper();
        }
        return instance;
    }

    public PpcPortalProductMapper() {
        prepareProductNameMapping();
        this.productByNameMapping = prepareProductByNameMapping();
    }

    @TestVisible
    private void prepareProductNameMapping() {
        Map<String, PpcProductToSalesforceMapping__mdt> rows = PpcProductToSalesforceMapping__mdt.getAll();
        for (PpcProductToSalesforceMapping__mdt row : rows.values()) {
            String prodName = row.ProductName__c;
            String salesforceProduct = row.SalesforceProductName__c;
            partnerProducts.add(prodName);
            salesforceProducts.add(salesforceProduct);
            this.productInfos.add(new ProductInfo(prodName, salesforceProduct));
        }

        System.debug('Products: ' + partnerProducts);
    }

    @TestVisible
    private Map<String, Product2> prepareProductByNameMapping() {
        Map<String, Product2> result = new Map<String, Product2>();
        List<Product2> salesforceProducts = new List<Product2>([
            SELECT Id, Name, Family
            FROM Product2
            WHERE Name IN :salesforceProducts
        ]);
        System.debug('Found ' + salesforceProducts.size() + ' Salesforce products.');
        for (Product2 product : salesforceProducts) {
            result.put(product.Name, product);
            System.debug('SF Product: ' + product.Name + ' => ' + product.Id);
        }
        return result;
    }


    public PortalProductMapper.MappingResult mapProduct(String fullProductName) {
        PortalProductMapper.MappingResult result = new PortalProductMapper.MappingResult();

        // Full key is productName:platform:edition. Full search is done first.
        String productName = fullProductName.substringBefore('(').trim();
        result.portalProduct = productName;
        System.debug('Searching for product: ' + productName);

        // Search using all parameters
        List<ProductInfo> productSearchResult = searchProductInfos(true, productName);

        // Found one exact match!
        if (productSearchResult.size() == 1) {
            String salesforceProductName = productSearchResult[0].salesforceProductName;
            if (salesforceProductName != null) {
                result.found = true;
                result.product = productByNameMapping.get(salesforceProductName);
                result.info = 'Success';
                System.debug('### FOUND! ' + result.product);
            } else {
                result.found = false;
                result.info += '[K] Found mapping but NO Salesforce product id found for Salesforce product: ' + salesforceProductName;
                System.debug('### FOUND (' + productName + ')in Metadata. NOT FOUND (' + salesforceProductName + ') as Product2!');
            }
        } else {
            result.found = false;
            result.info = '[D] Product name unknown: ' + productName + '.';
            System.debug('### NOT FOUND! ' + productName);
        }

        return result;
    }

    @TestVisible
    private List<ProductInfo> searchProductInfos(
        Boolean matchProduct, String productName
    ) {
        List<ProductInfo> result = new List<ProductInfo>();
        for (ProductInfo info : productInfos) {
            if ((!matchProduct || info.productName.equalsIgnoreCase(productName))) {
                result.add(info);
            }
        }
        return result;
    }

    public class ProductInfo {
        @AuraEnabled public String productName;
        @AuraEnabled public String salesforceProductName;

        public ProductInfo(String productName, String salesforceProductName) {
            this.productName = productName;
            this.salesforceProductName = (salesforceProductName != null && salesforceProductName.containsIgnoreCase('null')) ? null : salesforceProductName;
        }
    }

}