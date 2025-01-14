/**
 * Filename: PortalProductMapper.cls
 *
 * @Description This class is used to map partner portal products to Salesforce products.
 *              It is used to map partner portal products to Salesforce products.
 *
 */

public with sharing class PortalProductMapper {

    private static PortalProductMapper instance;
    private final Set<String> partnerProducts = new Set<String>();    // Set of all unique partner products
    private final Set<String> partnerPlatforms = new Set<String>();   // Set of all unique partner platforms
    private final Set<String> partnerEditions = new Set<String>();    // Set of all unique partner editions
    private final Set<String> salesforceProducts = new Set<String>(); // Set of all unique Salesforce products
    private final Map<String, Product2> productByNameMapping;         // Mapping from Salesforce Product Name to Product2 records
    private final Product2 defaultCloudProduct;
    private final Product2 defaultDatacenterProduct;
    private final List<ProductInfo> productInfos = new List<PortalProductMapper.ProductInfo>();

    public static PortalProductMapper getInstance() {
        if (instance == null) {
            instance = new PortalProductMapper();
        }
        return instance;
    }

    public PortalProductMapper() {
        prepareProductNameMapping();
        this.productByNameMapping = prepareProductByNameMapping();
        this.defaultCloudProduct = getDefaultCloudProduct();
        this.defaultDatacenterProduct = getDefaultDatacenterProduct();
    }

    @TestVisible
    private void prepareProductNameMapping() {
        Map<String, String> result = new Map<String, String>();
        Map<String, PortalProductToSalesforceMapping__mdt> rows = PortalProductToSalesforceMapping__mdt.getAll();
        for (PortalProductToSalesforceMapping__mdt row : rows.values()) {
            String prodName = row.ProductName__c;
            String platform = row.Platform__c;
            String edition = row.Edition__c;
            String salesforceProduct = row.SalesforceProductName__c;
            Boolean zeroSEN = row.ZeroSEN__c;
            partnerProducts.add(prodName);
            partnerPlatforms.add(platform);
            partnerEditions.add(edition);
            salesforceProducts.add(salesforceProduct);
            this.productInfos.add(new ProductInfo(prodName, platform, edition, salesforceProduct, zeroSEN));
        }

        System.debug('Products: ' + partnerProducts);
        System.debug('Platforms: ' + partnerPlatforms);
        System.debug('Editions: ' + partnerEditions);
    }

    @TestVisible
    private Map<String, Product2> prepareProductByNameMapping() {
        Map<String, Product2> result = new Map<String, Product2>();
        List<Product2> salesforceProducts = new List<Product2>([
            SELECT Id, Name, Family
            FROM Product2
            WHERE Name IN :salesforceProducts
        ]);
        // System.debug('Found ' + salesforceProducts.size() + ' Salesforce products.');
        for (Product2 product : salesforceProducts) {
            result.put(product.Name, product);
            // System.debug('SF Product: ' + product.Name + ' => ' + product.Id);
        }
        return result;
    }

    @TestVisible
    private Product2 getDefaultCloudProduct() {
        List<ProductInfo> searchProductInfos = searchProductInfos(
            true, null,
            true, 'CLOUD',
            true, null);
        System.debug('getDefaultCloudProduct: ' + searchProductInfos);
        if (searchProductInfos.size() == 1) {
            Product2 product = productByNameMapping.get(searchProductInfos[0].salesforceProductName);
            return product;
        }
        return null;
    }

    @TestVisible
    private Product2 getDefaultDatacenterProduct() {
        List<ProductInfo> searchProductInfos = searchProductInfos(
            true, null,
            true, 'DATACENTER',
            true, null);
        System.debug('getDefaultDatacenterProduct: ' + searchProductInfos);
        if (searchProductInfos.size() == 1) {
            Product2 product = productByNameMapping.get(searchProductInfos[0].salesforceProductName);
            return product;
        }
        return null;
    }

    /**
     * Search for product infos that match the search criteria.
     *
     * @param matchProduct - Whether to match the product name
     * @param productName - The product name to match
     * @param matchPlatform - Whether to match the platform
     * @param platform - The platform to match
     * @param matchEdition - Whether to match the edition
     * @param edition - The edition to match
     *
     * @return A list of product infos that match the search criteria
     */
    @TestVisible
    private List<ProductInfo> searchProductInfos(
        Boolean matchProduct, String productName,
        Boolean matchPlatform, String platform,
        Boolean matchEdition, String edition
    ) {
        List<ProductInfo> result = new List<ProductInfo>();
        for (ProductInfo info : productInfos) {
            if ((!matchProduct || info.productName == productName) &&
                (!matchPlatform || info.platform == platform) &&
                (!matchEdition || info.edition == edition)) {
                result.add(info);
            }
        }
        return result;
    }

    /**
     * Maps a partner portal product to a Salesforce product.
     *
     * @param productName - Name of the partner portal product
     * @param platform - The platform of the partner portal product
     * @param edition - The edition of the partner portal product
     *
     * @return The result of the mapping. Structure containing the fields:
     *         - product: The Salesforce product that the partner portal product maps to
     *         - info: Information about the mapping process
     *         - found: Whether the mapping was successful
     *         - If the mapping was successful, the product field will contain the Salesforce product
     */
    public MappingResult mapProduct(String productName, String platform, String edition) {
        MappingResult result = new MappingResult();
        result.portalProduct = 'Partner Portal Product Name: ' + productName + ',  Platform: ' + platform + ',  Edition: ' + edition;

        // Full key is productName:platform:edition. Full search is done first.
        System.debug('Searching for product: ' + productName + ' platform: ' + platform + ' edition: ' + edition);

        // Search using all parameters
        List<PortalProductMapper.ProductInfo> productSearchResult = searchProductInfos(true, productName, true, platform, true, edition);

        // Found one exact match!
        if (productSearchResult.size() == 1) {
            result.found = true;
            // Generic Atlassian Cloud product containing generic SEN?
            if (productSearchResult[0].salesforceProductName == null) {
                result.globalSEN = true;
                result.zeroSEN = productSearchResult[0].zeroSEN;
                return result;
            }

            result.product = productByNameMapping.get(productSearchResult[0].salesforceProductName);
            if (result.product == null) {
                result.found = false;
                result.info = '[A] Found mapping but NO Salesforce product id found for product: ' + productSearchResult[0];
            } else {
                result.zeroSEN = productSearchResult[0].zeroSEN;
                result.info = 'Success';
            }
            return result;
        }

        // Check if platform is valid
        if (!partnerPlatforms.contains(platform)) {
            result.info += '[B] Partner portal product platform unknown: ' + platform + ' for product: ' + productName + ' and edition: ' + edition + '. ';
        }

        // Check if edition is valid
        if (!partnerEditions.contains(edition)) {
            result.info += '[C] Partner portal product edition unknown: ' + edition + ' for product ' + productName + ' and platform: ' + platform + '. ';
        }

        // Return validation errors for edition and platform
        if (result.info.length() > 0) {
            return result;
        }

        // If full key search failed, try to find the product by name only.
        List<PortalProductMapper.ProductInfo> productSearchNameOnlyResult =
            searchProductInfos(true, productName, false, null, false, null);

        if (productSearchNameOnlyResult.size() == 0) {
            result.info = '[D] Product name unknown: ' + productName + '. ';

            // If full key search failed, try to find the product by platform only.
            List<PortalProductMapper.ProductInfo> productSearchPlatformOnlyResult =
                searchProductInfos(true, null, true, platform, true, null);

            if (productSearchPlatformOnlyResult.size() == 1) {
                result.info += '[E] Found default product for platform: ' + platform + '. ';
                result.product = productByNameMapping.get(productSearchPlatformOnlyResult[0].salesforceProductName);
                if (result.product == null) {
                    result.found = false;
                    result.info += '[F] Found mapping but NO Salesforce product id found for Salesforce product: ' + productSearchPlatformOnlyResult[0].salesforceProductName;
                } else {
                    result.zeroSEN = productSearchPlatformOnlyResult[0].zeroSEN;
                    result.found = true;
                }
            } else {
                result.info += '[G] No default product found for platform: ' + platform + '. ';
            }
        } else if (productSearchNameOnlyResult.size() == 1) {
            result.info = '[I] Product name found (single match): ' + productName + '. ';

            // If full key search failed, try to find the product by platform only.
            List<PortalProductMapper.ProductInfo> productSearchPlatformOnlyResult =
                searchProductInfos(true, null, true, platform, true, null);

            if (productSearchPlatformOnlyResult.size() == 1) {
                result.info += '[J] Found default product for platform: ' + platform + '. ';
                result.product = productByNameMapping.get(productSearchPlatformOnlyResult[0].salesforceProductName);
                if (result.product == null) {
                    result.found = false;
                    result.info += '[K] Found mapping but NO Salesforce product id found for Salesforce product: ' + productSearchPlatformOnlyResult[0].salesforceProductName;
                } else {
                    result.zeroSEN = productSearchPlatformOnlyResult[0].zeroSEN;
                    result.found = true;
                }
            } else {
                result.info += '[L] No default product found for platform: ' + platform + '. ';
            }
        } else {
            result.info += '[H] Found ' + productSearchNameOnlyResult.size() + ' products partial match on product name: ' + productName +
                (productSearchNameOnlyResult[0].platform == platform ? ' and platform: ' + platform : '') +
                (productSearchNameOnlyResult[0].edition == edition ? ' and edition: ' + edition : '') +
                '. ';
            result.found = false;
            result.product = null;
        }

        return result;
    }

    // ===================
    //   WRAPPER CLASSES
    // ===================

    public class MappingResult {
        @AuraEnabled public String portalProduct;
        @AuraEnabled public Product2 product;
        @AuraEnabled public String info;
        @AuraEnabled public Boolean found;
        @AuraEnabled public Boolean globalSEN;
        @AuraEnabled public Boolean zeroSEN;
        @AuraEnabled public String link;

        public MappingResult() {
            this.portalProduct = null;
            this.product = null;
            this.info = '';
            this.found = false;
            this.globalSEN = false;
            this.zeroSEN = false;
            this.link = null;
        }
    }

    public class ProductInfo {
        @AuraEnabled public String productName;
        @AuraEnabled public String platform;
        @AuraEnabled public String edition;
        @AuraEnabled public String salesforceProductName;
        @AuraEnabled public Boolean zeroSEN;

        public ProductInfo(String productName, String platform, String edition, String salesforceProductName, Boolean zeroSEN) {
            this.productName = productName;
            this.platform = platform;
            this.edition = edition;
            this.salesforceProductName = (salesforceProductName != null && salesforceProductName.containsIgnoreCase('null')) ? null : salesforceProductName;
            this.zeroSEN = (zeroSEN != null) ? zeroSEN : false;
        }
    }
}