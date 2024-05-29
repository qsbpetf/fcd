/*
* Test for the updateProductsBuyingPricesBatch and the updateProductsBuyingPricesScheduler class
* @author Constance Rouge - Ceterna Ltd
* @createddate 23/05/2018
*/
@IsTest
public class updateProductsBuyingPricesTest {
    
    public static testmethod void testBatchWithBothExchangeRate(){
        
        List<Product2> otherVendorProductPList=new List<Product2>();
        for(Integer i=0;i<20;i++){
            Product2 prod=TestDataFactory.getProduct();
            prod.Name+=i;
            otherVendorProductPList.add(prod);
        }
        insert otherVendorProductPList;
        List<Product2> internalPList=new List<Product2>();
        for(Integer i=0;i<20;i++){
            Product2 prod=TestDataFactory.getProduct();
            prod.Name+=i;
            prod.Family='Internal';
            internalPList.add(prod);
        }
        insert internalPList;
        
        Decimal EURRate=0.7;
        Decimal GBPRate=0.6;
        
        test.startTest();
        updateProductsBuyingPricesBatch b = new updateProductsBuyingPricesBatch(EURRate, GBPRate); 
        database.executebatch(b);
        test.stopTest();
        
        Product2 otherVendorProd=[SELECT Id, Academic_Cost_price_Dollars__c, Academic_Cost_price_Euros__c, Academic_Cost_price_Pounds__c,Commercial_Cost_price_Dollars__c, Commercial_Cost_price_Euros__c, Commercial_Cost_price_Pounds__c 
                                  FROM Product2 WHERE Family='OtherVendorProduct' LIMIT 1];
        System.assertEquals(10, otherVendorProd.Academic_Cost_price_Dollars__c);
        System.assertEquals(7, otherVendorProd.Academic_Cost_price_Euros__c);
        System.assertEquals(6, otherVendorProd.Academic_Cost_price_Pounds__c);
        System.assertEquals(20, otherVendorProd.Commercial_Cost_price_Dollars__c);
        System.assertEquals(14, otherVendorProd.Commercial_Cost_price_Euros__c);
        System.assertEquals(12, otherVendorProd.Commercial_Cost_price_Pounds__c);
        
        
        Product2 internalProd=[SELECT Id, Academic_Cost_price_Dollars__c, Academic_Cost_price_Euros__c, Academic_Cost_price_Pounds__c,Commercial_Cost_price_Dollars__c, Commercial_Cost_price_Euros__c, Commercial_Cost_price_Pounds__c 
                               FROM Product2 WHERE Family='Internal' LIMIT 1];
        System.assertEquals(10, internalProd.Academic_Cost_price_Dollars__c);
        System.assertEquals(8, internalProd.Academic_Cost_price_Euros__c);
        System.assertEquals(7, internalProd.Academic_Cost_price_Pounds__c);
        System.assertEquals(20, internalProd.Commercial_Cost_price_Dollars__c);
        System.assertEquals(16, internalProd.Commercial_Cost_price_Euros__c);
        System.assertEquals(14, internalProd.Commercial_Cost_price_Pounds__c);
        
    }
    
    
    public static testmethod void testScheduler(){
        Buying_Exchange_Rate__c rate=TestDataFactory.getRate();//new Buying_Exchange_Rate__c(Created_from_Test_Class__c=true, Start_Date__c=System.today()-1, Exchange_Rate_from_USD_to_EUR__c=0.8, Exchange_Rate_from_USD_to_GBP__c=0.7);
        insert rate;
        Test.StartTest();
        updateProductsBuyingPricesScheduler sh1 = new updateProductsBuyingPricesScheduler();      
        String sch = '0 0 23 * * ?';
        system.schedule('Test check', sch, sh1);
        Test.stopTest();
        
    }
}