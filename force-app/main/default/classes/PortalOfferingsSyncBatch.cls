/**
 * Created by peterfriberg on 2024-12-01.
 */

public with sharing class PortalOfferingsSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful{

    static public final Integer PAGE_SIZE = 50;
    static public final String DEFAULT_QUERY = 'SELECT Id, Name, AtlassianId__c FROM AtlassianProduct__c';

    private Integer totalOfferings;
    @TestVisible private String query;

    public PortalOfferingsSyncBatch() {
        this.query = DEFAULT_QUERY;
        this.totalOfferings = 0;
    }

    public static void run() {
        Database.executeBatch(new PortalOfferingsSyncBatch(), PAGE_SIZE);
    }

    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(this.query);
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope){
        PortalCommerceApiOfferings api = PortalCommerceApiOfferings.getInstance();
        AtlassianOffering__c[] atlassianOfferings = new AtlassianOffering__c[0];

        for (SObject record : scope) {
            AtlassianProduct__c product = (AtlassianProduct__c) record;
            PortalCommerceApiOfferings.OfferingList offerings = api.getOfferings('FI', product.AtlassianId__c, PAGE_SIZE, null);
            System.debug('### Got ' + offerings.values.size() + ' offerings for product: ' + product.AtlassianId__c + '  ' + product.Name);

            for (PortalCommerceApiOfferings.OfferingInfo offering : offerings.values) {
                AtlassianOffering__c atlassianOffering = new AtlassianOffering__c();
                atlassianOffering.AtlassianId__c = offering.id;
                atlassianOffering.AtlassianProduct__c = product.Id;
                atlassianOffering.Name = offering.name;
                atlassianOffering.Ari__c = offering.ari;
                atlassianOffering.UpdatedAtUnixTime__c = offering.updatedAt;
                atlassianOffering.HostingType__c = offering.hostingType;
                atlassianOffering.Level__c = offering.level;
                atlassianOffering.AtlassianProductId__c = offering.productId;
                atlassianOffering.PricingType__c = offering.pricingType;
                atlassianOffering.Status__c = offering.status;
                atlassianOffering.Version__c = offering.version;
                atlassianOffering.SupportedBillingSystems__c = String.join(offering.supportedBillingSystems, ';');

                atlassianOfferings.add(atlassianOffering);
            }

            this.totalOfferings += offerings.values.size();
        }

        upsert atlassianOfferings AtlassianId__c;
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('### Synced ' + this.totalOfferings + ' offerings');
    }
}