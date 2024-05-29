/**
* Batch class to update all the pricebook entries of the products in the right families
* @author Constance Rouge - Ceterna Ltd
* @createddate 23/05/2018
*/

global class updatePricebookEntriesBatch implements Database.Batchable<sObject>{
    
    global final String Query;
    global final Decimal EURRate;
    global final Decimal GBPRate;
    
    
    global updatePricebookEntriesBatch(Decimal EURRate, Decimal GBPRate){
        Query='SELECT Id, (SELECT Id, Pricebook2Id, CurrencyIsoCode, UnitPrice FROM PricebookEntries) FROM Product2 WHERE Family LIKE \'Atlassian%\' OR Family = \'OtherVendorProduct\' OR Family = \'Hosting (CV)\' OR Family =\'X Squad Licenses\'';
        this.EURRate=EURRate;
        this.GBPRate=GBPRate;        
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<sObject> scope){
        List<Product2> allProd = (List<Product2>)scope;  
        
        List<PricebookEntry> pEntriesToUpdate=new List<PricebookEntry>();
        List<PricebookEntry> pEntriesToInsert=new List<PricebookEntry>();
        //The, for each product, we sort the pricebook entries into a map linking each pricebook Id to the list of pricebook entries for that pricebook and that product
        //This means that, for each product, there should be only one pricebook entry per pricebook, per currency
        for(Product2 prod : allProd){
            List<PricebookEntry> pEntriesForProd=prod.PricebookEntries;
            Map<Id, List<PricebookEntry>> pBIdEntries=new Map<Id, List<PricebookEntry>>();
            for(PricebookEntry pE: pEntriesForProd){
                List<PricebookEntry> pEntries=pBIdEntries.get(pE.Pricebook2Id);
                if(pEntries==null) pEntries=new List<PricebookEntry>();
                pEntries.add(pE);
                pBIdEntries.put(pE.Pricebook2Id,pEntries);
            }
            //Identify the dollar pricebook entry, the euro pricebook entry and the gbp pricebook entry
            //recalculate gbp and euro prices
            for(Id i: pBIdEntries.keySet()){
                PricebookEntry usdEntry;
                PricebookEntry eurEntry;
                PricebookEntry gbpEntry;
                for(PricebookEntry pE:pBIdEntries.get(i)){
                    if(pE.CurrencyIsoCode=='USD') usdEntry=pE;
                    if(pE.CurrencyIsoCode=='EUR') eurEntry=pE;
                    if(pE.CurrencyIsoCode=='GBP') gbpEntry=pE;
                }
                if(usdEntry!=null && eurEntry!=null && EURRate!=null){
                    eurEntry.UnitPrice=usdEntry.UnitPrice *EURRate;
                    pEntriesToUpdate.add(eurEntry);
                }
                else{
                    if(usdEntry!=null && EURRate!=null){
                        eurEntry=new PricebookEntry(Pricebook2Id=i, Product2Id=prod.Id, CurrencyIsoCode='EUR', UnitPrice=usdEntry.UnitPrice *EURRate); 
                        pEntriesToInsert.add(eurEntry);
                    }
                }
                if(usdEntry!=null && gbpEntry!=null && GBPRate!=null){
                    gbpEntry.UnitPrice=usdEntry.UnitPrice*GBPRate;
                    pEntriesToUpdate.add(gbpEntry);
                }
                else{
                    if(usdEntry!=null && GBPRate!=null){
                        gbpEntry=new PricebookEntry(Pricebook2Id=i, Product2Id=prod.Id, CurrencyIsoCode='GBP', UnitPrice=usdEntry.UnitPrice*GBPRate);
                        pEntriesToInsert.add(gbpEntry);
                    }
                }
            }
            
        }
        Database.update(pEntriesToUpdate, false);
        Database.insert(pEntriesToInsert, false);
    }
    
    global void finish(Database.BatchableContext BC){
    }
}