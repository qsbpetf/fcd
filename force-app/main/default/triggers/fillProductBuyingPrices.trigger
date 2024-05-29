/*
* Trigger to fill the buying prices in Euro and GBP when a product is created or updated
* @author Constance Rouge - Ceterna Ltd
* @createddate 07/06/2018
*/


trigger fillProductBuyingPrices on Product2 (before insert, before update) {
        
    List<Buying_Exchange_Rate__c> buyingRatesList=[SELECT Id, Exchange_Rate_from_USD_to_EUR__c, Exchange_Rate_from_USD_to_GBP__c FROM Buying_Exchange_Rate__c WHERE Start_Date__c<=TODAY ORDER BY Start_Date__c DESC LIMIT 1];
    Decimal buyingEURRate;
    Decimal buyingGBPRate;
    if(buyingRatesList.size()==1){
        buyingEURRate=buyingRatesList[0].Exchange_Rate_from_USD_to_EUR__c;
        buyingGBPRate=buyingRatesList[0].Exchange_Rate_from_USD_to_GBP__c;
    }
    
    for(Product2 p : trigger.new){
        if((Trigger.isInsert ||(Trigger.isUpdate && (p.Academic_Cost_price_Dollars__c!=trigger.oldMap.get(p.Id).Academic_Cost_price_Dollars__c || p.Commercial_Cost_price_Dollars__c!=trigger.oldMap.get(p.Id).Commercial_Cost_price_Dollars__c))
        )&& p.Family!=null && (p.Family.startsWith('Atlassian') || p.Family =='OtherVendorProduct' || p.Family =='X Squad Licenses')){
            if(buyingEURRate!=null && p.Academic_Cost_price_Dollars__c!=null) p.Academic_Cost_price_Euros__c=p.Academic_Cost_price_Dollars__c*buyingEURRate;
            if(buyingGBPRate!=null && p.Academic_Cost_price_Dollars__c!=null) p.Academic_Cost_price_Pounds__c=p.Academic_Cost_price_Dollars__c*buyingGBPRate;
            if(buyingEURRate!=null && p.Commercial_Cost_price_Dollars__c!=null) p.Commercial_Cost_price_Euros__c=p.Commercial_Cost_price_Dollars__c*buyingEURRate;
            if(buyingGBPRate!=null && p.Commercial_Cost_price_Dollars__c!=null) p.Commercial_Cost_price_Pounds__c=p.Commercial_Cost_price_Dollars__c*buyingGBPRate;
        }
    }
    
}