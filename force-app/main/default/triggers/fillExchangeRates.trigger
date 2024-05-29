/*
* Trigger to fill the custom exchange rates when the opportunity product is created
* @author Constance Rouge - Ceterna Ltd
* @createddate 24/05/2018
*/

trigger fillExchangeRates on OpportunityLineItem (before insert) {
    
    List<Buying_Exchange_Rate__c> buyingRatesList=[SELECT Id, Exchange_Rate_from_USD_to_EUR__c, Exchange_Rate_from_USD_to_GBP__c FROM Buying_Exchange_Rate__c WHERE Start_Date__c<=YESTERDAY ORDER BY Start_Date__c DESC LIMIT 1];
    Decimal buyingEURRate;
    Decimal buyingGBPRate;

    if(buyingRatesList.size()==1){
        buyingEURRate=buyingRatesList[0].Exchange_Rate_from_USD_to_EUR__c;
        buyingGBPRate=buyingRatesList[0].Exchange_Rate_from_USD_to_GBP__c;
    }
    
    for(OpportunityLineItem opLI:Trigger.New){
        opLI.Buying_Exchange_Rate_from_USD_to_EUR__c=buyingEURRate;
        opLI.Buying_Exchange_Rate_from_USD_to_GBP__c=buyingGBPRate;
        opLI.List_Exchange_Rate_from_USD_to_EUR__c=buyingEURRate;
        opLI.List_Exchange_Rate_from_USD_to_GBP__c=buyingGBPRate;
    }
}