/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 *
 * The @IsTest class annotation indicates this class only contains test
 * methods. Classes defined with the @IsTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */@IsTest private class OpportunityLineItemControllerTest {
    @IsTest static void getOpportunityLineItemsTestSuccess() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Map<String, Object> result = OpportunityLineItemController.getOpportunityLineItems(opp.Id, 0, 30, 'Name', 'ASC');
        List<OpportunityLineItem> olis = (List<OpportunityLineItem>) result.get('olis');
        System.assertEquals(2, olis.size(), 'There was an unexpected number of opportunity line items');
    }

    @IsTest static void getOpportunityLineItemsByIdsTestSuccess() {
        OpportunityLineItem oli = [
            SELECT Id
            FROM OpportunityLineItem
            LIMIT 1
        ];
        List<Id> oliIds = new List<Id> {
            oli.Id
        };
        List<OpportunityLineItem> olis = OpportunityLineItemController.getOpportunityLineItemsByIds(oliIds);
        System.debug(olis);
        System.assertEquals(1, olis.size(), 'There was an unexpected number of opportunity line items');
    }

    @IsTest static void getTypePicklistValuesTestSuccess() {
        List<Map<String, String>> typePicklistValues = OpportunityLineItemController.getTypePicklistValues();
        System.assertNotEquals(0, typePicklistValues.size(), 'typePicklistValues was empty');
    }

//    @IsTest static void insertOpportunityLineItemsTestSuccess() {
//        Opportunity oppo = [SELECT Id FROM Opportunity LIMIT 1];
//        PricebookEntry pbe = [SELECT Product2Id FROM PricebookEntry LIMIT 1];
//        Map<String, OpportunityLineItem> olis = new Map<String, OpportunityLineItem>();
//        OpportunityLineItem oli = new OpportunityLineItem();
//        oli.OpportunityId = oppo.Id;
//        oli.Product2Id = pbe.Product2Id;
//        oli.UnitPrice = 100.00;
//        oli.Quantity = 1;
//        olis.put('123-ABC', oli);
//
//        Map<String, Object> result = OpportunityLineItemController.insertOpportunityLineItems(olis);
//        Map<String, Object> errors = (Map<String, Object>) result.get('errors');
//        System.assertEquals(0, errors.keySet().size(), 'insertOpportunityLineItems didn\'t return the correct number of errors');
//    }

    @IsTest static void insertOpportunityLineItemsTestFailure() {
        Opportunity oppo = [SELECT Id FROM Opportunity LIMIT 1];
        PricebookEntry pbe = [SELECT Product2Id FROM PricebookEntry LIMIT 1];
        Map<String, OpportunityLineItem> olis = new Map<String, OpportunityLineItem>();
        OpportunityLineItem oli = new OpportunityLineItem();
        oli.OpportunityId = oppo.Id;
        oli.Product2Id = null;
        olis.put('123-ABC', oli);

        Map<String, Object> result = OpportunityLineItemController.insertOpportunityLineItems(olis);
        Map<String, Object> errors = (Map<String, Object>) result.get('errors');
        Map<String, Object> res = (Map<String, Object>) errors.get('rows');
        Map<String, Object> re = (Map<String, Object>) res.get('123-ABC');
        List<String> messages = (List<String>) re.get('messages');
        System.assertEquals(1, messages.size(), 'insertOpportunityLineItems didn\'t return the correct number of errors');
    }

    @IsTest static void updateOpportunityLineItemsTestSuccess() {
        OpportunityLineItem oli = [SELECT Id FROM OpportunityLineItem LIMIT 1];
        oli.Quantity = 2;
        Map<String, OpportunityLineItem> olis = new Map<String, OpportunityLineItem> {
            oli.Id => oli
        };

        Map<String, Object> result = OpportunityLineItemController.updateOpportunityLineItems(olis);
        Map<String, Object> errors = (Map<String, Object>) result.get('errors');
        System.assertEquals(0, errors.keySet().size(), 'updateOpportunityLineItems didn\'t return the correct number of errors');
    }

    @IsTest static void updateOpportunityLineItemsTestFailure() {
        OpportunityLineItem oli = [SELECT Id FROM OpportunityLineItem LIMIT 1];
        oli.Quantity = null;
        Map<String, OpportunityLineItem> olis = new Map<String, OpportunityLineItem> {
            oli.Id => oli
        };
        Map<String, Object> result = OpportunityLineItemController.updateOpportunityLineItems(olis);

        Map<String, Object> errors = (Map<String, Object>) result.get('errors');
        Map<String, Object> res = (Map<String, Object>) errors.get('rows');
        Map<String, Object> re = (Map<String, Object>) res.get(oli.Id);
        List<String> messages = (List<String>) re.get('messages');
        System.assertEquals(1, messages.size(), 'updateOpportunityLineItems didn\'t return the correct number of errors');
    }

    @IsTest static void deleteOpportunityLineItemsTestSuccess() {
        OpportunityLineItem oli = [SELECT Id FROM OpportunityLineItem LIMIT 1];
        Id oliId = oli.Id;
        List<String> oliIds = new List<String> {
            oliId
        };
        Map<String, Object> result = OpportunityLineItemController.deleteOpportunityLineItems(oliIds);

        Map<String, String> errors = (Map<String, String>) result.get('errors');
        System.assertEquals(0, errors.keySet().size(), 'deleteOpportunityLineItems didn\'t return the correct number of errors');
    }

    @TestSetup static void makeData() {
        Product2 p = new Product2();
        p.Name = 'Test Product1';
        p.IsActive = true;
        p.Unlimited_Users__c = true;
        insert p;

        PricebookEntry pbe = new PricebookEntry();
        pbe.Pricebook2Id = Test.getStandardPricebookId();
        pbe.Product2Id = p.Id;
        pbe.UnitPrice = 100.00;
        pbe.IsActive = true;
        insert pbe;

        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opportunity';
        opp.StageName = 'Prospecting';
        opp.CloseDate = Date.today();
        opp.Pricebook2Id = Test.getStandardPricebookId();
        insert opp;

        OpportunityLineItem oli1 = new OpportunityLineItem();
        oli1.OpportunityId = opp.Id;
        oli1.Product2Id = pbe.Product2Id;
        oli1.UnitPrice = 100.00;
        oli1.Quantity = 1;
        oli1.Renewal__c = 'New';
        insert oli1;

        OpportunityLineItem oli2 = new OpportunityLineItem();
        oli2.OpportunityId = opp.Id;
        oli2.Product2Id = pbe.Product2Id;
        oli2.UnitPrice = 200.00;
        oli2.Quantity = 2;
        oli2.Renewal__c = 'New';
        insert oli2;
    }
}