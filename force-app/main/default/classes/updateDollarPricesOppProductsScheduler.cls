/*
* Scheduler for the updateDollarPricesOppProductsBatch batch class
* It makes the batch run when there is a new buying exchange rate or a new standard conversion rate
* @author Constance Rouge - Ceterna Ltd
* @createddate 23/05/2018
*/

global class updateDollarPricesOppProductsScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        List<Buying_Exchange_Rate__c> buyingRatesList=[SELECT Id, Exchange_Rate_from_USD_to_EUR__c, Exchange_Rate_from_USD_to_GBP__c FROM Buying_Exchange_Rate__c WHERE Start_Date__c=YESTERDAY];
        Decimal buyingEURRate;
        Decimal buyingGBPRate;
        
        if(buyingRatesList.size()==1){
            buyingEURRate=buyingRatesList[0].Exchange_Rate_from_USD_to_EUR__c;
            buyingGBPRate=buyingRatesList[0].Exchange_Rate_from_USD_to_GBP__c;
        }
        if(buyingEURRate!=null || buyingGBPRate!=null){
            updateDollarPricesOppProductsBatch b = new updateDollarPricesOppProductsBatch(buyingEURRate, buyingGBPRate); 
            database.executebatch(b, 20);
        }
    }
    
}