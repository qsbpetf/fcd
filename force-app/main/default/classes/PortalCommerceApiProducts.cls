/**
 * Created by peterfriberg on 2024-06-05.
 */

public with sharing class PortalCommerceApiProducts {

//    static private PortalCommerceApiProducts instance;
//    static private PortalCommerceApiClient client;
//
//    static public PortalCommerceApiProducts getInstance() {
//        if (instance == null) {
//            instance = new PortalCommerceApiProducts();
//            client = PortalCommerceApiClient.getInstance();
//        }
//        return instance;
//    }
//
//    public ProductList getProducts(String office, Integer pageSize, String nextId) {
//        HttpResponse response = client.getProducts(office, null, pageSize, nextId);
//        ProductList products = (ProductList) JSON.deserialize(response.getBody(), ProductList.class);
//        return products;
//    }
//
//    @AuraEnabled
//    public static ProductList getProductsStatic(String office, Integer pageSize, String nextId) {
//        PortalCommerceApiClient client = PortalCommerceApiClient.getInstance();
//        PortalCommerceApiProducts instance = PortalCommerceApiProducts.getInstance();
//        return instance.getProducts(office, pageSize, nextId);
//    }
//
//    // ==================
//    //  WRAPPER CLASSES
//    // ==================
//
//    public class ProductList {
//        @AuraEnabled public List<ProductInfo> values;
//        @AuraEnabled public String nextId;
//    }
//
//    public class ProductInfo {
//        @AuraEnabled public String id;
//        @AuraEnabled public String name;
//        @AuraEnabled public String status;
//    }
}