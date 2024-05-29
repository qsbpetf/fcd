/*
* Test for the updateDollarPricesOppProductsBatch and the updateDollarPricesOppProductsScheduler class
* @author Constance Rouge - Ceterna Ltd
* @createddate 23/05/2018
*/

@IsTest
public class updateDollarPricesOppProductsTest {
    
    public static testmethod void testBatchWithEUR(){
        Buying_Exchange_Rate__c rate=TestDataFactory.getRate();
        insert rate;
                
        Product2 prod=TestDataFactory.getProduct();
        insert prod;
        
        Id pricebookId=test.getStandardPricebookId();
        PricebookEntry pEEUR=TestDataFactory.getPbEntry(pricebookId, prod.Id, 'EUR');
        insert pEEUR;
        Account accEUR=TestDataFactory.getAccount('Angola', 'EUR');
        insert accEUR;
        Opportunity oppEUR=TestDataFactory.getOpp(accEUR.id, 'EUR');
        insert oppEUR;
        OpportunityLineItem opLIEUR=TestDataFactory.getOppProd(pEEUR.Id, oppEUR.Id);
        insert opLIEUR;
        
        opLIEUR=[SELECT Id, UnitPrice, Unit_Buy_Price__c, Buying_Exchange_Rate_from_USD_to_EUR__c, Buying_Exchange_Rate_from_USD_to_GBP__c, Unit_Buy_Price_in_USD__c, Unit_List_Price_in_USD__c FROM OpportunityLineItem WHERE Id=:opLIEUR.Id];
        System.assertEquals(0.8, opLIEUR.Buying_Exchange_Rate_from_USD_to_EUR__c);
        System.assertEquals(0.7, opLIEUR.Buying_Exchange_Rate_from_USD_to_GBP__c); 
        
        Decimal buyingEURRate=0.7;
        Decimal buyingGBPRate=0.6;
        
        test.startTest();
        updateDollarPricesOppProductsBatch b = new updateDollarPricesOppProductsBatch(buyingEURRate, buyingGBPRate); 
        database.executebatch(b);
        test.stopTest();
        
        opLIEUR=[SELECT Id, UnitPrice, Unit_Buy_Price__c, Buying_Exchange_Rate_from_USD_to_EUR__c, Buying_Exchange_Rate_from_USD_to_GBP__c, Unit_Buy_Price_in_USD__c, Unit_List_Price_in_USD__c FROM OpportunityLineItem WHERE Id=:opLIEUR.Id];
        System.assertEquals(0.7, opLIEUR.Buying_Exchange_Rate_from_USD_to_EUR__c);
        System.assertEquals(0.6, opLIEUR.Buying_Exchange_Rate_from_USD_to_GBP__c); 
    }
    
    
    public static testmethod void testBatchWithGBP(){
        Buying_Exchange_Rate__c rate=TestDataFactory.getRate();
        insert rate;
        
        Product2 prod=TestDataFactory.getProduct();//
        insert prod;
        
        Id pricebookId=test.getStandardPricebookId();
        PricebookEntry pEGBP=TestDataFactory.getPbEntry(pricebookId, prod.Id, 'GBP');
        insert pEGBP;
        
        Account accGBP=TestDataFactory.getAccount('Angola', 'GBP');
        insert accGBP;
        Opportunity oppGBP=TestDataFactory.getOpp(accGBP.id, 'GBP');
        insert oppGBP;
        OpportunityLineItem opLIGBP=TestDataFactory.getOppProd(pEGBP.Id, oppGBP.Id);
        insert opLIGBP;
        
        opLIGBP=[SELECT Id, UnitPrice, Unit_Buy_Price__c, Buying_Exchange_Rate_from_USD_to_EUR__c, Buying_Exchange_Rate_from_USD_to_GBP__c, Unit_Buy_Price_in_USD__c, Unit_List_Price_in_USD__c FROM OpportunityLineItem WHERE Id=:opLIGBP.Id];
        System.assertEquals(0.8, opLIGBP.Buying_Exchange_Rate_from_USD_to_EUR__c);
        System.assertEquals(0.7, opLIGBP.Buying_Exchange_Rate_from_USD_to_GBP__c); 
        
        Decimal buyingEURRate=0.7;
        Decimal buyingGBPRate=0.6;
        
        test.startTest();
        updateDollarPricesOppProductsBatch b = new updateDollarPricesOppProductsBatch(buyingEURRate, buyingGBPRate); 
        database.executebatch(b);
        test.stopTest();
        
        opLIGBP=[SELECT Id, UnitPrice, Unit_Buy_Price__c, Buying_Exchange_Rate_from_USD_to_EUR__c, Buying_Exchange_Rate_from_USD_to_GBP__c, Unit_Buy_Price_in_USD__c, Unit_List_Price_in_USD__c FROM OpportunityLineItem WHERE Id=:opLIGBP.Id];
        System.assertEquals(0.7, opLIGBP.Buying_Exchange_Rate_from_USD_to_EUR__c);
        System.assertEquals(0.6, opLIGBP.Buying_Exchange_Rate_from_USD_to_GBP__c); 
    }
    
    
    
    public static testmethod void testScheduler(){
        Buying_Exchange_Rate__c rate=TestDataFactory.getRate();
        insert rate;
        Test.StartTest();
        updateDollarPricesOppProductsScheduler sh1 = new updateDollarPricesOppProductsScheduler();      
        String sch = '0 0 23 * * ?';
        system.schedule('Test check', sch, sh1);
        Test.stopTest();
        
    }
}