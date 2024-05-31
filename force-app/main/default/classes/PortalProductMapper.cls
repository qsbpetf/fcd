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
            partnerProducts.add(prodName);
            partnerPlatforms.add(platform);
            partnerEditions.add(edition);
            salesforceProducts.add(salesforceProduct);
            this.productInfos.add(new ProductInfo(prodName, platform, edition, salesforceProduct));
        }

        System.debug('Products: ' + partnerProducts);
        System.debug('Platforms: ' + partnerPlatforms);
        System.debug('Editions: ' + partnerEditions);
    }

    @TestVisible
    private Map<String, Product2> prepareProductByNameMapping() {
        Map<String, Product2> result = new Map<String, Product2>();
        List<Product2> salesforceProducts = new List<Product2>([
            SELECT Id, Name
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
            // if matchProduct is true, productName must match
            // if matchPlatform is true, platform must match
            // if matchEdition is true, edition must match
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
        result.info = '';

        // Full key is productName:platform:edition. Full search is done first.
        System.debug('Searching for product: ' + productName + ' platform: ' + platform + ' edition: ' + edition);

        // Search using all parameters
        List<PortalProductMapper.ProductInfo> productSearchResult = searchProductInfos(true, productName, true, platform, true, edition);

        // Found one exact match!
        if (productSearchResult.size() == 1) {
            result.product = productByNameMapping.get(productSearchResult[0].salesforceProductName);
            result.found = true;
            if (result.product == null) {
                result.found = false;
                result.info = '[A] Found mapping but NO Salesforce product id found for product: ' + productSearchResult[0];
            } else {
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
        } else {
            result.info += '[E] Found ' + productSearchNameOnlyResult.size() + ' products partial match on product name: ' + productName +
                (productSearchNameOnlyResult[0].platform == platform ? ' and platform: ' + platform : '') +
                (productSearchNameOnlyResult[0].edition == edition ? ' and edition: ' + edition : '') +
                '. ';

            // If full key search failed, try to find the product by name only.
            List<PortalProductMapper.ProductInfo> productSearchPlatformOnlyResult =
                searchProductInfos(true, null, true, platform, true, null);

            if (productSearchPlatformOnlyResult.size() == 1) {
                result.info += '[F] Found default product for platform: ' + platform + '. ';
                result.product = productByNameMapping.get(productSearchPlatformOnlyResult[0].salesforceProductName);
                if (result.product == null) {
                    result.found = false;
                    result.info += '[G] Found mapping but NO Salesforce product id found for Salesforce product: ' + productSearchPlatformOnlyResult[0].salesforceProductName;
                } else {
                    result.found = true;
                }
                return result;
            }
        }

        result.info += '[H] No default product found for product: ' + productName + ' platform: ' + platform + ' edition: ' + edition + '. ';
        return result;
    }

    // ===================
    //   WRAPPER CLASSES
    // ===================

    public class MappingResult {
        public Product2 product;
        public String info;
        public Boolean found;
    }

    public class ProductInfo {
        public String productName;
        public String platform;
        public String edition;
        public String salesforceProductName;

        public ProductInfo(String productName, String platform, String edition, String salesforceProductName) {
            this.productName = productName;
            this.platform = platform;
            this.edition = edition;
            this.salesforceProductName = salesforceProductName;
        }
    }
}