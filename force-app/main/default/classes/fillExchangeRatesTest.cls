/*
* Test for the fillExchangeRates trigger
* @author Constance Rouge - Ceterna Ltd
* @createddate 24/05/2018
*/

@IsTest
public class fillExchangeRatesTest {
    
    public static testmethod void testFillExchangeRates(){

        Buying_Exchange_Rate__c rate=TestDataFactory.getRate();
        insert rate;

        Product2 prod=TestDataFactory.getProduct();
        insert prod;

        Id pricebookId=test.getStandardPricebookId();
        PricebookEntry pEUSD=TestDataFactory.getPbEntry(pricebookId, prod.Id, 'USD');
        insert pEUSD;

        Account accUSD=TestDataFactory.getAccount('Angola', 'USD');
        insert accUSD;
        Opportunity oppUSD=TestDataFactory.getOpp(accUSD.id, 'USD');
        insert oppUSD;
        OpportunityLineItem opLIUSD=TestDataFactory.getOppProd(pEUSD.Id, oppUSD.Id);
        insert opLIUSD;


        opLIUSD=[SELECT Id, UnitPrice, Unit_Buy_Price__c, List_Exchange_Rate_from_USD_to_EUR__c, List_Exchange_Rate_from_USD_to_GBP__c, Buying_Exchange_Rate_from_USD_to_EUR__c, Buying_Exchange_Rate_from_USD_to_GBP__c, Unit_Buy_Price_in_USD__c, Unit_List_Price_in_USD__c FROM OpportunityLineItem WHERE Id=:opLIUSD.Id];
        System.assertEquals(opLIUSD.Buying_Exchange_Rate_from_USD_to_EUR__c, 0.8);
        System.assertEquals(opLIUSD.Buying_Exchange_Rate_from_USD_to_GBP__c, 0.7);
        System.assertEquals(opLIUSD.List_Exchange_Rate_from_USD_to_EUR__c, 0.8);
        System.assertEquals(opLIUSD.List_Exchange_Rate_from_USD_to_GBP__c, 0.7);

    }
}