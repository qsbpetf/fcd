/**
 * Created by peterfriberg on 2024-11-29.
 */

public with sharing class PortalProductSyncQueueable implements Queueable, Database.AllowsCallouts {

    private final static PortalCommerceApiProducts products = PortalCommerceApiProducts.getInstance();
    private final static Integer PAGE_SIZE = 50;
    private static Integer loopCount = 1;
    private static Integer totalProducts = 0;
    private static Integer longestProductNameLength = 0;
    @TestVisible private final String nextId = null;
    @TestVisible private String currentOffice = 'FI';

    public PortalProductSyncQueueable() {
    }

    public PortalProductSyncQueueable(String nextId, Integer count, Integer total, Integer productNameLength) {
        this.nextId = nextId;
        loopCount = count;
        totalProducts = total;
        longestProductNameLength = productNameLength;
    }

    public void execute(QueueableContext context) {
        syncProducts();
    }

    @TestVisible
    private void syncProducts() {
        System.debug('### Count ' + loopCount + ' Syncing products from FI office with nextId: ' + this.nextId);
        PortalCommerceApiProducts.ProductList productList = products.getProducts(this.currentOffice, PAGE_SIZE, this.nextId);

        List<AtlassianProduct__c> atlassianProducts = new List<AtlassianProduct__c>();

        for (PortalCommerceApiProducts.ProductInfo product : productList.values) {
            System.debug('-- Syncing Product: ' + product.id + ' with name: ' + product.name);

            AtlassianProduct__c atlassianProduct = new AtlassianProduct__c();
            atlassianProduct.AtlassianId__c = product.id;
            atlassianProduct.Name = product.name.left(79);
            atlassianProduct.Ari__c = product.ari;
            atlassianProduct.Status__c = product.status;
            atlassianProduct.Version__c = product.version;
            atlassianProduct.UpdatedAtUnixTime__c = product.updatedAt;
            atlassianProduct.SupportedBillingSystems__c = String.join(product.supportedBillingSystems, ';');
            atlassianProducts.add(atlassianProduct);

            if (product.name.length() > longestProductNameLength) {
                longestProductNameLength = product.name.length();
                System.debug('### Longest product name so far: ' + product.name);
            }
            totalProducts++;
        }

        upsert atlassianProducts AtlassianId__c;

        if (productList.nextId != null) {
            System.debug('### Scheduling next sync with nextId: ' + productList.nextId);
            if (Test.isRunningTest()) {
                return;
            }
            System.enqueueJob(new PortalProductSyncQueueable(productList.nextId, loopCount + 1, totalProducts, longestProductNameLength));
        } else {
            System.debug('### All ' + totalProducts + ' products synced, used ' + loopCount + ' loops with ' + PAGE_SIZE + ' products per loop');
            System.debug('### Longest product name length: ' + longestProductNameLength);
        }
    }
}