/*
* Batch class to update the exchange rates on all open opportunity product
* @author Constance Rouge - Ceterna Ltd
* @createddate 23/05/2018
*/

global class updateDollarPricesOppProductsBatch implements Database.Batchable<sObject>{
    
    global final String Query;
    global final Decimal buyingEURRate;
    global final Decimal buyingGBPRate;
    
    global updateDollarPricesOppProductsBatch(Decimal buyingEURRate, Decimal buyingGBPRate){
        Query='SELECT Id, CurrencyIsoCode, Buying_Exchange_Rate_from_USD_to_EUR__c, UnitPrice, Buying_Exchange_Rate_from_USD_to_GBP__c FROM OpportunityLineItem WHERE Opportunity.IsClosed=FALSE';
        this.buyingEURRate=buyingEURRate;
        this.buyingGBPRate=buyingGBPRate;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<OpportunityLineItem> scope){
        
        List<OpportunityLineItem> allOppLI = (List<OpportunityLineItem>)scope;
        List<OpportunityLineItem> allOppLIToUpdate = new List<OpportunityLineItem>();
        for(OpportunityLineItem opLI : allOppLI){
            if(buyingEURRate!=null) opLI.Buying_Exchange_Rate_from_USD_to_EUR__c=buyingEURRate;
            if(buyingGBPRate!=null) opLI.Buying_Exchange_Rate_from_USD_to_GBP__c=buyingGBPRate;
            allOppLIToUpdate.add(opLi);
        }
        Database.update(allOppLIToUpdate, false);
    }
    
    global void finish(Database.BatchableContext BC){
    }
}