/*
* Test for the fillProductBuyingPrices trigger
* @author Constance Rouge - Ceterna Ltd
* @createddate 07/06/2018
*/

@IsTest
public class fillProductBuyingPricesTest {
    
    public static testmethod void testFillProductBuyingPrices(){

        Buying_Exchange_Rate__c rate=TestDataFactory.getRate();
        insert rate;

        Product2 prod=TestDataFactory.getProduct();
        prod.Academic_Cost_price_Euros__c=null;
        prod.Academic_Cost_price_Pounds__c=null;
        prod.Commercial_Cost_price_Euros__c=null;
        prod.Commercial_Cost_price_Pounds__c=null;
        insert prod;

        prod=[SELECT Id, Academic_Cost_price_Dollars__c, Academic_Cost_price_Euros__c, Academic_Cost_price_Pounds__c,
              Commercial_Cost_price_Dollars__c, Commercial_Cost_price_Euros__c, Commercial_Cost_price_Pounds__c
              FROM Product2 WHERE Id=:prod.Id];
        System.assertEquals(8, prod.Academic_Cost_price_Euros__c);
        System.assertEquals(7, prod.Academic_Cost_price_Pounds__c);
        System.assertEquals(16, prod.Commercial_Cost_price_Euros__c);
        System.assertEquals(14, prod.Commercial_Cost_price_Pounds__c);

        prod.Academic_Cost_price_Dollars__c=20;
        prod.Commercial_Cost_price_Dollars__c=30;
        update prod;
        prod=[SELECT Id, Academic_Cost_price_Dollars__c, Academic_Cost_price_Euros__c, Academic_Cost_price_Pounds__c,
              Commercial_Cost_price_Dollars__c, Commercial_Cost_price_Euros__c, Commercial_Cost_price_Pounds__c
              FROM Product2 WHERE Id=:prod.Id];
        System.assertEquals(16, prod.Academic_Cost_price_Euros__c);
        System.assertEquals(14, prod.Academic_Cost_price_Pounds__c);
        System.assertEquals(24, prod.Commercial_Cost_price_Euros__c);
        System.assertEquals(21, prod.Commercial_Cost_price_Pounds__c);

    }
}