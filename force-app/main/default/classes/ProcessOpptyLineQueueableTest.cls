/**
 * Created by peterfriberg on 2025-03-13.
 */

@IsTest
private class ProcessOpptyLineQueueableTest {

    static void setup() {
        // create default product
        String defaultProductName;
        Map<String, PpcProductToSalesforceMapping__mdt> rows = PpcProductToSalesforceMapping__mdt.getAll();
        for (PpcProductToSalesforceMapping__mdt row : rows.values()) {
            String prodName = row.ProductName__c;
            String salesforceProduct = row.SalesforceProductName__c;
            if (prodName == null) {
                defaultProductName = salesforceProduct;
                break;
            }
        }

        Product2 prod = TestDataFactory.getProduct();
        System.debug(prod);
        prod.Name = defaultProductName;
        insert prod;

        PricebookEntry pbe = TestDataFactory.getPbEntry(Test.getStandardPricebookId(), prod.Id, 'EUR');
        insert pbe;

        AtlassianOffering__c offering = new AtlassianOffering__c();
        offering.Name = 'Test Offering';
        offering.AtlassianId__c = '123';
        offering.Product__c = prod.Id;
        insert offering;
    }

    @IsTest
    static void testBehaviorWithNoLines() {
        setup();

        Account acc = TestDataFactory.getAccount('Finland', 'EUR');
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.Pricebook2Id = Test.getStandardPricebookId();
        opp.StageName = 'Prospecting';
        opp.CloseDate = Date.today().addDays(10);
        insert opp;

        Test.startTest();
        opp.StageName = 'Closing';

        OpportunityData oppData = new OpportunityData(opp.Id, opp.StageName, new List<OpportunityLineItem>(), null);
        ProcessOpportunityLinesQueueable queueable = new ProcessOpportunityLinesQueueable(oppData);
        System.enqueueJob(queueable);
        Test.stopTest();

        List<OpportunityLineItem> insertedItems = [SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        System.assertEquals(0, insertedItems.size(), 'Should have no items');
    }

    @IsTest
    static void testBehaviorWithTwoLines() {
        setup();

        Account acc = TestDataFactory.getAccount('Finland', 'EUR');
        insert acc;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'EUR');
        opp.Pricebook2Id = Test.getStandardPricebookId();
        opp.StageName = 'Prospecting';
        opp.CloseDate = Date.today().addDays(10);
        insert opp;

        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :opp.Pricebook2Id LIMIT 1];
        List<OpportunityLineItem> items = new List<OpportunityLineItem>();
        OpportunityLineItem item1 = new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = pbe.Id, Quantity = 1, Renewal__c = 'Renewal (CV Owned)');
        OpportunityLineItem item2 = new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = pbe.Id, Quantity = 2, Renewal__c = 'Renewal (CV Owned)');
        items.addAll(new List<OpportunityLineItem>{ item1, item2 });

        Test.startTest();
        opp.StageName = 'Closing';

        PendingInvoice__c pendingInvoice = new PendingInvoice__c();
        pendingInvoice.Name = 'Test Invoice';
        pendingInvoice.Invoice_JSON__c = '{}';
        pendingInvoice.Status__c = 'Waiting';
        pendingInvoice.Error__c = null;
        pendingInvoice.RetryCount__c = 0;
        pendingInvoice.Account__c = acc.Id;
        pendingInvoice.Opportunity__c = opp.Id;
        insert pendingInvoice;

        OpportunityData oppData = new OpportunityData(opp.Id, opp.StageName, items, pendingInvoice.Id);
        ProcessOpportunityLinesQueueable queueable = new ProcessOpportunityLinesQueueable(oppData);
        System.enqueueJob(queueable);
        Test.stopTest();

        List<OpportunityLineItem> insertedItems = [SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        System.assertEquals(2, insertedItems.size(), 'Should have two items');
        Opportunity updatedOpportunity = [SELECT Id, StageName FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Closing', updatedOpportunity.StageName, 'Should have updated stage');
    }
}