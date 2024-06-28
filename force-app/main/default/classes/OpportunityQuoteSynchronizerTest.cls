@IsTest public without sharing class OpportunityQuoteSynchronizerTest {

    @IsTest public static void test() {
        MappageOpportuniteDevis__c parentsMapping = new MappageOpportuniteDevis__c(Name = 'Description_TextFormula__c', ChampDevis__c = 'Description');
        insert parentsMapping;

        MappageOliQli__c childrenMapping = new MappageOliQli__c(Name = 'Additional_Info__c', ChampLigneDeDevis__c = 'Additional_Info__c');
        insert childrenMapping;

        Product2 p1 = new Product2(Name = 'p1', IsActive = true, Unlimited_Users__c = true);
        insert p1;

        PricebookEntry pe1 = new PricebookEntry(Product2Id = p1.Id, Pricebook2Id = Test.getStandardPricebookId(), UnitPrice = 1, IsActive = true);
        insert pe1;

        Product2 p2 = new Product2(Name = 'p2', IsActive = true, Unlimited_Users__c = true);
        insert p2;

        PricebookEntry pe2 = new PricebookEntry(Product2Id = p2.Id, Pricebook2Id = Test.getStandardPricebookId(), UnitPrice = 1, IsActive = true);
        insert pe2;

        Opportunity opp = new Opportunity(Name = 'opp1', StageName = 'New', CloseDate = System.today(), Description_TextFormula__c = 'Test');
        insert opp;

        OpportunityLineItem oli1 = new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = pe1.Id, Quantity = 1, UnitPrice = 1, Additional_Info__c = 'InfoP1', Renewal__c = 'Renewal (New to CV)');
        insert oli1;

        OpportunityLineItem oli2 = new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = pe2.Id, Quantity = 1, UnitPrice = 1, Additional_Info__c = 'InfoP2', Renewal__c = 'Renewal (New to CV)');
        insert oli2;

        System.debug('oli1: ' + oli1.Id);
        System.debug('oli2: ' + oli2.Id);

        Test.startTest();
        Quote q = new Quote(Name = 'q1', OpportunityId = opp.Id);
        insert q;

        q = [SELECT Description FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Test', q.Description);

        insert new List<QuoteLineItem> { //insertion dans le test. En situation réelle, Salesforce les créer automatiquementnew QuoteLineItem(OpportunityLineItemId = oli1.Id, QuoteId = q.Id, PricebookEntryId = oli1.PricebookEntryId, Quantity = oli1.Quantity, UnitPrice = oli1.UnitPrice, Product2Id = oli1.Product2Id), new QuoteLineItem(OpportunityLineItemId = oli2.Id, QuoteId = q.Id, PricebookEntryId = oli2.PricebookEntryId, Quantity = oli2.Quantity, UnitPrice = oli2.UnitPrice, Product2Id = oli2.Product2Id)
        };

        List<QuoteLineItem> items = [
            SELECT Additional_Info__c
            FROM QuoteLineItem
            WHERE QuoteId = :q.Id
            ORDER BY Product2.Name
        ];
//        System.assertEquals(2, items.size());
//        System.assertEquals('InfoP1', items[0].Additional_Info__c);
//        System.assertEquals('InfoP2', items[1].Additional_Info__c);

        ///

        q.Description = 'Test2';
        update q;

        q = [SELECT Description FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Test2', q.Description);

//        delete items[1];
//        System.assertEquals(1, [SELECT Id, OpportunityLineItemId, Additional_Info__c, Quantity FROM QuoteLineItem ORDER BY OpportunityLineItemId].size());
//
        QuoteLineItem qli = new QuoteLineItem(QuoteId = q.Id, OpportunityLineItemId = null, PricebookEntryId = pe2.Id, Quantity = 2, UnitPrice = 1, Product2Id = p2.Id, Additional_Info__c = 'InfoP3');
        // items[0].Additional_Info__c = 'InfoP1.2';
        upsert new List<QuoteLineItem> {
            /* items[0], */ qli
        };

        // System.assertEquals(2, [SELECT Id, OpportunityLineItemId, Additional_Info__c, Quantity FROM QuoteLineItem ORDER BY OpportunityLineItemId].size());

        System.debug('---> sync');
        opp.SyncedQuoteId = q.Id;
        // update opp;
        System.debug('---/ sync');
        Test.stopTest();

//        List<Id> itemIds = new List<Id> {
//            items[0].Id, qli.Id
//        };
//
//        items = [
//            SELECT Id, OpportunityLineItemId, Additional_Info__c, Quantity
//            FROM QuoteLineItem
//            WHERE Id IN :itemIds
//            ORDER BY OpportunityLineItemId
//        ];
//        opp = [SELECT Description_TextFormula__c, (SELECT Id, Quantity, Additional_Info__c FROM OpportunityLineItems ORDER BY Id) FROM Opportunity WHERE Id = :opp.Id];
//
//        System.assertEquals('Test2', opp.Description_TextFormula__c);
//        for (Quotelineitem truc : items)System.debug(truc.OpportunityLineItemId + ' : ' + truc.Additional_Info__c);
//        System.assertEquals(2, items.size());
//        System.assertEquals(2, opp.OpportunityLineItems.size());
//        System.assertEquals(items[0].OpportunityLineItemId, opp.OpportunityLineItems[0].Id);
//        System.assertEquals(items[0].Additional_Info__c, opp.OpportunityLineItems[0].Additional_Info__c);
//        System.assertEquals(items[1].OpportunityLineItemId, opp.OpportunityLineItems[1].Id);
//        System.assertEquals(items[1].Additional_Info__c, opp.OpportunityLineItems[1].Additional_Info__c, opp.OpportunityLineItems[1].Id);
    }
}