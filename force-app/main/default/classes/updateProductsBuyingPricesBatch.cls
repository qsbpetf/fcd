/**
* Batch class to update the buying prices of all the products in the right families
* @author Constance Rouge - Ceterna Ltd
* @createddate 23/05/2018
*/
global class updateProductsBuyingPricesBatch implements Database.Batchable<sObject>{
    
    global final String Query;
    global final Decimal EURRate;
    global final Decimal GBPRate;
    
    
    global updateProductsBuyingPricesBatch(Decimal EURRate, Decimal GBPRate){
        Query='SELECT Id, Academic_Cost_price_Dollars__c, Academic_Cost_price_Euros__c, Academic_Cost_price_Pounds__c,Commercial_Cost_price_Dollars__c, Commercial_Cost_price_Euros__c, Commercial_Cost_price_Pounds__c FROM Product2 WHERE Family LIKE \'Atlassian%\' OR Family = \'OtherVendorProduct\' OR Family =\'X Squad Licenses\'';
        this.EURRate=EURRate;
        this.GBPRate=GBPRate;     
        System.debug(EURRate);
        System.debug(GBPRate);
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<sObject> scope){
        List<Product2> allProds = (List<Product2>)scope;
        
        for(Product2 p : allProds){
            if(EURRate!=null) p.Academic_Cost_price_Euros__c=p.Academic_Cost_price_Dollars__c*EURRate;
            if(GBPRate!=null) p.Academic_Cost_price_Pounds__c=p.Academic_Cost_price_Dollars__c*GBPRate;
            if(EURRate!=null) p.Commercial_Cost_price_Euros__c=p.Commercial_Cost_price_Dollars__c*EURRate;
            if(GBPRate!=null) p.Commercial_Cost_price_Pounds__c=p.Commercial_Cost_price_Dollars__c*GBPRate;
        }
        Database.update(allProds, false);
    }
    
    global void finish(Database.BatchableContext BC){
    }
}