/*
* Test for the updatePricebookEntriesBatch and the updatePricebookEntriesScheduler class
* @author Constance Rouge - Ceterna Ltd
* @createddate 23/05/2018
*/
@IsTest
public class updatePricebookEntriesTest {
    
    public static testmethod void testBatchWithBothExchangeRate(){
        
        List<Product2> pList=new List<Product2>();
        for(Integer i=0;i<20;i++){
            Product2 prod=TestDataFactory.getProduct();
            prod.Name='Test PricebookEntriesBatch'+i;
            pList.add(prod);
        }
        insert pList;
        
        Id pricebookId=test.getStandardPricebookId();
        
        List<PricebookEntry> pEList=new List<PricebookEntry>();
        for(Product2 p:pList){
            pEList.add(TestDataFactory.getPbEntry(pricebookId, p.Id, 'USD'));
            pEList.add(TestDataFactory.getPbEntry(pricebookId, p.Id, 'EUR'));
            pEList.add(TestDataFactory.getPbEntry(pricebookId, p.Id, 'GBP'));
        }
        insert pEList;
        
        Decimal GBPRate=2;
        Decimal EURRate=4;
        
        test.startTest();
        updatePricebookEntriesBatch b = new updatePricebookEntriesBatch(EURRate, GBPRate); 
        database.executebatch(b);
        test.stopTest();
        
        PricebookEntry USDpE=[SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntry WHERE CurrencyIsoCode='USD' AND Product2Id=:pList[0].Id];
        System.assertEquals(1, USDpE.UnitPrice);
        PricebookEntry GBPpE=[SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntry WHERE CurrencyIsoCode='GBP' AND Product2Id=:pList[0].Id];
        System.assertEquals(2, GBPpE.UnitPrice);
        PricebookEntry EURpE=[SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntry WHERE CurrencyIsoCode='EUR' AND Product2Id=:pList[0].Id];
        System.assertEquals(4, EURpE.UnitPrice);
        
    }
    
    public static testmethod void testBatchWithOnlyUSDEntry(){
        
        List<Product2> pList=new List<Product2>();
        for(Integer i=0;i<20;i++){
            Product2 prod=TestDataFactory.getProduct();
            prod.Name='Test PricebookEntriesBatch'+i;
            pList.add(prod);
        }
        insert pList;
        
        Id pricebookId=test.getStandardPricebookId();
        
        List<PricebookEntry> pEList=new List<PricebookEntry>();
        for(Product2 p:pList){
            pEList.add(TestDataFactory.getPbEntry(pricebookId, p.Id, 'USD'));
        }
        insert pEList;
        
        Decimal GBPRate=2;
        Decimal EURRate=4;
        
        test.startTest();
        updatePricebookEntriesBatch b = new updatePricebookEntriesBatch(EURRate, GBPRate); 
        database.executebatch(b);
        test.stopTest();

        PricebookEntry USDpE=[SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntry WHERE CurrencyIsoCode='USD' AND Product2Id=:pList[0].Id];
        System.assertEquals(1, USDpE.UnitPrice);
        PricebookEntry GBPpE=[SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntry WHERE CurrencyIsoCode='GBP' AND Product2Id=:pList[0].Id];
        System.assertEquals(2, GBPpE.UnitPrice);
        PricebookEntry EURpE=[SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntry WHERE CurrencyIsoCode='EUR' AND Product2Id=:pList[0].Id];
        System.assertEquals(4, EURpE.UnitPrice);
        
    }
    
    
    public static testmethod void testBatchWithEURRateNull(){
        
        List<Product2> pList=new List<Product2>();
        for(Integer i=0;i<20;i++){
            Product2 prod=TestDataFactory.getProduct();
            prod.Name='Test PricebookEntriesBatch'+i;
            pList.add(prod);
        }
        insert pList;
        
        Id pricebookId=test.getStandardPricebookId();
        
        List<PricebookEntry> pEList=new List<PricebookEntry>();
        for(Product2 p:pList){
            pEList.add(TestDataFactory.getPbEntry(pricebookId, p.Id, 'USD'));
            pEList.add(TestDataFactory.getPbEntry(pricebookId, p.Id, 'EUR'));
            pEList.add(TestDataFactory.getPbEntry(pricebookId, p.Id, 'GBP'));
        }
        insert pEList;
        
        Decimal GBPRate=2;
        Decimal EURRate;
        
        test.startTest();
        updatePricebookEntriesBatch b = new updatePricebookEntriesBatch(EURRate, GBPRate); 
        database.executebatch(b);
        test.stopTest();
        
        PricebookEntry USDpE=[SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntry WHERE CurrencyIsoCode='USD' AND Product2Id=:pList[0].Id];
        System.assertEquals(1, USDpE.UnitPrice);
        PricebookEntry GBPpE=[SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntry WHERE CurrencyIsoCode='GBP' AND Product2Id=:pList[0].Id];
        System.assertEquals(2, GBPpE.UnitPrice);
        PricebookEntry EURpE=[SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntry WHERE CurrencyIsoCode='EUR' AND Product2Id=:pList[0].Id];
        System.assertEquals(1, EURpE.UnitPrice);
        
    }
    
    
    public static testmethod void testScheduler(){
        Buying_Exchange_Rate__c rate=TestDataFactory.getRate();
        insert rate;
        Test.StartTest();
        updatePricebookEntriesScheduler sh1 = new updatePricebookEntriesScheduler();      
        String sch = '0 0 23 * * ?';
        system.schedule('Test check', sch, sh1);
        Test.stopTest();
        
    }
}