/*
* Scheduler for the updateProductsBuyingPricesBatch batch class
* It makes the batch run when there is a new buying exchange rate
* @author Constance Rouge - Ceterna Ltd
* @createddate 23/05/2018
*/
global class updateProductsBuyingPricesScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        List<Buying_Exchange_Rate__c> ratesList=[SELECT Id, Exchange_Rate_from_USD_to_EUR__c, Exchange_Rate_from_USD_to_GBP__c FROM Buying_Exchange_Rate__c WHERE Start_Date__c=YESTERDAY];
        if(ratesList.size()==1){
            Decimal EURRate=ratesList[0].Exchange_Rate_from_USD_to_EUR__c;
            Decimal GBPRate=ratesList[0].Exchange_Rate_from_USD_to_GBP__c;
            updateProductsBuyingPricesBatch b = new updateProductsBuyingPricesBatch(EURRate, GBPRate); 
            database.executebatch(b);
        }
    }
}