/**
 * Created by peterfriberg on 2024-09-03.
 */

public with sharing class PpcPortalProductMapper {

    private static PpcPortalProductMapper instance;
    private final Set<String> partnerProducts = new Set<String>();    // Set of all unique partner products
    private final Set<String> salesforceProducts = new Set<String>(); // Set of all unique Salesforce products
    private final Map<String, Product2> productByNameMapping;         // Mapping from Salesforce Product Name to Product2 records
    public final Product2 defaultCloudProduct;
    private final List<ProductInfo> productInfos = new List<ProductInfo>();

    private static Map<String, Product2> productByOfferingId = new Map<String, Product2>();
    private static Map<String, String> atlassianProductByOfferingId = new Map<String, String>();

    public static PpcPortalProductMapper getInstance() {
        if (instance == null) {
            instance = new PpcPortalProductMapper();
        }
        return instance;
    }

    public PpcPortalProductMapper() {
        prepareProductNameMapping();
        this.productByNameMapping = prepareProductByNameMapping();
        this.defaultCloudProduct = getDefaultCloudProduct();
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

    public static void mapProductByQuoteLineItems(List<PortalCommerceApiQuotes.BillLineItem> quoteLineItems) {
        Set<String> offeringIds = new Set<String>();
        for (PortalCommerceApiQuotes.BillLineItem quoteLine : quoteLineItems) {
            offeringIds.add(quoteLine.offeringId);
        }
        System.debug('OFFERING IDS: ' + offeringIds);
        mapProductByOfferingId(offeringIds);
        System.debug('MAPPING: ' + productByOfferingId);
    }

    public static void mapProductByInvoiceLineItems(List<PortalCommerceApiInvoices.InvoiceItem> invoiceLineItems) {
        Set<String> offeringIds = new Set<String>();
        for (PortalCommerceApiInvoices.InvoiceItem lineItem : invoiceLineItems) {
            offeringIds.add(lineItem.offeringKey);
        }
        System.debug('OFFERING IDS: ' + offeringIds);
        mapProductByOfferingId(offeringIds);
        System.debug('MAPPING: ' + productByOfferingId);
    }

    public static Map<String, AtlassianOffering__c> getOfferingsByOfferingKey(Set<String> offeringIds) {
        Map<String, AtlassianOffering__c> result = new Map<String, AtlassianOffering__c>();
        List<AtlassianOffering__c> offerings = new List<AtlassianOffering__c>([
            SELECT
                Id,
                Name,
                AtlassianId__c,
                AtlassianProductId__c,
                AtlassianProduct__r.Name,
                Product__c,
                Product__r.Name
            FROM AtlassianOffering__c
            WHERE AtlassianId__c IN :offeringIds
        ]);

        for (AtlassianOffering__c offering : offerings) {
            result.put(offering.AtlassianId__c, offering);
        }

        return result;
    }

    private static void mapProductByOfferingId(Set<String> offeringIds) {
        List<AtlassianOffering__c> offerings = getOfferingsByOfferingKey(offeringIds).values();

        Set<Id> productIds = new Set<Id>();
        for (AtlassianOffering__c offering : offerings) {
            productIds.add(offering.Product__c);
            productByOfferingId.put(offering.AtlassianId__c, offering.Product__r);
            atlassianProductByOfferingId.put(offering.AtlassianId__c, offering.AtlassianProductId__c);
        }
    }

    public PortalProductMapper.MappingResult mapProductByOfferingId(String offeringId) {
        PortalProductMapper.MappingResult result = new PortalProductMapper.MappingResult();
        return result;
    }

    public PortalProductMapper.MappingResult mapProduct(PortalCommerceApiQuotes.BillLineItem quoteLine) {
        PortalProductMapper.MappingResult result = new PortalProductMapper.MappingResult();
        result.product = productByOfferingId.get(quoteLine.offeringId);
        if (result.product != null) {
            result.found = true;
            result.info = 'Success';
        } else {
            result.product = defaultCloudProduct;
            result.found = false;
            result.info = '[K] No product found for offering: ' + quoteLine.offeringId;
            result.link = 'Offering: ' + quoteLine.offeringId + ' --> AtlassianProduct: ' + atlassianProductByOfferingId.get(quoteLine.offeringId) + '  :  ' + quoteLine.description;
        }
        return result;
    }

    public PortalProductMapper.MappingResult mapProduct(PortalCommerceApiInvoices.InvoiceItem lineItem) {
        PortalProductMapper.MappingResult result = new PortalProductMapper.MappingResult();
        result.product = productByOfferingId.get(lineItem.offeringKey);
        if (result.product != null) {
            result.found = true;
            result.info = 'Success';
        } else {
            result.product = defaultCloudProduct;
            result.found = false;
            result.info = '[K] No product found for offering: ' + lineItem.offeringKey;
            result.link = 'Offering: ' + lineItem.offeringKey + ' --> AtlassianProduct: ' + atlassianProductByOfferingId.get(lineItem.offeringKey) + '  :  ' + lineItem.description;
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
            return result;
        }

        if (productSearchResult.size() == 0)
        {
            result.info = '[D] Product name unknown: ' + productName + '.';
            System.debug('### SETTING DEFAULT PRODUCT! ' + productName);

            result.found = true;
            result.product = defaultCloudProduct;
        } else {
            result.found = false;
            result.info = '[E] Multiple products found for product: ' + productName + '.';
            System.debug('### MULTIPLE PRODUCTS FOUND! ' + productName);
        }

        return result;
    }

    @TestVisible
    private Product2 getDefaultCloudProduct() {
        List<ProductInfo> searchProductInfos = searchProductInfos(true, null);
        System.debug('getDefaultCloudProduct: ' + searchProductInfos);
        if (searchProductInfos.size() == 1) {
            Product2 product = productByNameMapping.get(searchProductInfos[0].salesforceProductName);
            return product;
        }
        return null;
    }

    @TestVisible
    private List<ProductInfo> searchProductInfos(
        Boolean matchProduct, String productName
    ) {
        List<ProductInfo> result = new List<ProductInfo>();
        for (ProductInfo info : productInfos) {
            if ((!matchProduct || (productName == null && info.salesforceProductName == null) || (info.productName == productName))) {
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