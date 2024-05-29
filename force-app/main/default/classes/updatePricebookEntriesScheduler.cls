/*
* Scheduler for the updatePricebookEntriesBatch batch class
* It makes the batch run when there is a new standard conversion rate
* @author Constance Rouge - Ceterna Ltd
* @createddate 23/05/2018
*/
global class updatePricebookEntriesScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        List<Buying_Exchange_Rate__c> buyingRatesList=[SELECT Id, Exchange_Rate_from_USD_to_EUR__c, Exchange_Rate_from_USD_to_GBP__c FROM Buying_Exchange_Rate__c WHERE Start_Date__c=YESTERDAY];
        
        Decimal EURRate;
        Decimal GBPRate;
        if(buyingRatesList.size()==1){
            EURRate=buyingRatesList[0].Exchange_Rate_from_USD_to_EUR__c;
            GBPRate=buyingRatesList[0].Exchange_Rate_from_USD_to_GBP__c;
        }
        if(EURRate!=null || GBPRate!=null){
            updatePricebookEntriesBatch b = new updatePricebookEntriesBatch(EURRate, GBPRate); 
            database.executebatch(b, 50);
        }
    }
}