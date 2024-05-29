/* 
* @author Alan Abishev - Ceterna LTD
* @createddate 21/04/2017
* @edited 14/08/2017
*/


/*=============================================================================
//
//    Trigger Handler for triggerCreateAssets
//    
//    1) When a new Asset is created or an old one is updated, a field CodeUseAssetId__c 
//       on opportunityLineItem is populated with a related Asset id (for creation confirmation )
//    2) If an OpportunityLineItem was created through batchOppFromAssets (from an Asset)
//       then, instead of creating a new Asset, update an existing related Asset (CreatedFromAssetId__c) 
//    
//=============================================================================*/


public class triggerCreateAssetsHandler extends TriggerHandler {
    /*This code is not being used and prevents any deployment as it is not properly covered by a test class
     * Therefore, its content is being commented out
     * For future developer working on this again, you will need to correct the test class triggerCreateAssetsHandlerTest
    
    public override void AfterUpdate(){
        logicAfter();
    }
    
    public void logicAfter(){
        
        //List of Opportunity
        List<Opportunity> lstOfOpp = new List<Opportunity>();
        List<String> lstOfOppIds = new List<String>();      // Opp ids
        List<String> lstOfOppAccIds = new List<String>();     // list for related Account of Opportunity (for debug)
        List<String> lstOfFromCreatedAssIds = new List<String>();    // List of createdFromIds
        List<Asset> lstOfAssToInsert = new List<Asset>();      // Assets to Insert
        List<Asset> lstOfAssToUpdate= new List<Asset>();      // Assets to Update
        List<String> lstOfOppLineIds = new List<String>();      
        List<Asset> lstOfInsertedAssets = new List<Asset>();
        Map<String,OpportunityLineItem> mpOfLineItems = new Map<String,OpportunityLineItem>();
        
        if (Trigger.isAfter){
            if (Trigger.isUpdate){
                for (Opportunity opp : (List<Opportunity>) Trigger.new){
                    
                    if(opp.StageName=='Order'){
                        lstOfOppIds.add(opp.id);
                        lstOfOppAccIds.add(opp.AccountId);
                        
                    }
                }
            }
        }
        
        
        lstOfOpp = [SELECT Accountid,(SELECT Name,Description,OpportunityId,PricebookEntryId,Total_List_Price_Incl_Discount__c,Is_Licence__c,License_Start_date__c,License_end_date__c,CurrencyIsoCode,Atlassian_License_Type__c,Product2Id,pricebook_ID__c,CodeUseAssetId__c,SEN_Technical_Contact__c,CreatedFromAssetId__c,Quantity,Product_Familly__c,SEN__c,Non_Licence_End_Date__c FROM Opportunity.OpportunityLineItems) FROM Opportunity WHERE Id IN:lstOfOppIds];
        
        System.debug('***********  '+lstOfOpp);
        for(Opportunity op:lstOfOpp){ 
            System.debug('***********1111  '+op.OpportunityLineItems);
            for(OpportunityLineItem opLine: op.OpportunityLineItems){
                lstOfFromCreatedAssIds.add(opLine.CreatedFromAssetId__c);
            }
        }
        
        List<Asset> lstOfRelAssets = [SELECT id,name FROM Asset WHERE id IN:lstOfFromCreatedAssIds];
        Map<String,Asset> mpOfAssets = new Map<String,Asset>();
        
        
        
        //Map
        
        if (!lstOfRelAssets.isEmpty()){
            for(Asset ass : lstOfRelAssets){
                if(lstOfRelAssets.isEmpty() || (!lstOfRelAssets.isEmpty() && !mpOfAssets.containsKey(ass.id))){
                    mpOfAssets.put(ass.id, ass);
                }          
            }  
        }   
        
        System.debug('List size:' + lstOfOpp.size());
        System.debug('List empty?:' + lstOfOpp.isEmpty());
        System.debug('Asset List:' + lstOfRelAssets.size() + ' '  + lstOfRelAssets);
        System.debug('Map:' + mpOfAssets);
        
        if (!lstOfOpp.isEmpty()){
            for(Opportunity op:lstOfOpp){ 
                
                for(OpportunityLineItem opLine: op.OpportunityLineItems){
                    
                    if (opLine.CodeUseAssetId__c==null){
                        
                        System.debug(opLine);
                        
                        Date installDate;
                        Date usageEndDate;
                        Boolean isLicense = opLine.Is_Licence__c;
                        Asset existingAss;
                        
                        lstOfOppLineIds.add(opLine.id);
                        mpOfLineItems.put(opLine.id, opLine);
                        
                        System.debug('isLicense:' + isLicense);

                        
                        //Date Assignment
                        if (opLine.Is_Licence__c==true && opLine.License_Start_date__c!=null && opLine.License_end_date__c!=null ){
                            installDate = opLine.License_Start_date__c;
                            usageEndDate = opLine.License_end_date__c;
                        }else if (opLine.Is_Licence__c==false && opLine.License_end_date__c==null && opLine.Non_Licence_End_Date__c!=null){
                            usageEndDate = opLine.Non_Licence_End_Date__c;
                            installDate  = date.today();  
                        }else if (opLine.Is_Licence__c==false){
                            installDate  = date.today();   
                        } 
                        
                        //If an oppLine was created from Asset, get the Asset 
                        if (!mpOfAssets.isEmpty()){
                            System.debug('Opp:' + opLine.CreatedFromAssetId__c);
                            existingAss = mpOfAssets.get(opLine.CreatedFromAssetId__c);
                            System.debug('Existing Asset:' + existingAss);
                        }
                        
                        // --Existing Asset Update--
                        if (existingAss!=null && opLine.CreatedFromAssetId__c!=null){
                            System.debug('--Existing Asset Update--');
                            
                            //existingAss.InstallDate = installDate;
                            existingAss.UsageEndDate = usageEndDate;
                            existingAss.SerialNumber = opLine.SEN__c;
                            existingAss.ContactId = opLine.SEN_Technical_Contact__c;
                            existingAss.Atlassian_License_Type__c = opLine.Atlassian_License_Type__c;
                            existingAss.CodeUseLineId__c = opLine.id;
                            lstOfAssToUpdate.add(existingAss);
                        // --New Asset Insert--
                        }else{
                            System.debug('--New Asset insert--');
                            Asset ass1 = new Asset(Name = opLine.Name,
                                                   AccountId = op.AccountId,
                                                   Quantity = opLine.Quantity,
                                                   Product2Id=opLine.Product2Id,
                                                   SerialNumber = opLine.SEN__c,
                                                   Price = opLine.Total_List_Price_Incl_Discount__c,
                                                   InstallDate = installDate,
                                                   ContactId = opLine.SEN_Technical_Contact__c,
                                                   UsageEndDate = usageEndDate,
                                                   PurchaseDate = date.today(),
                                                   CurrencyIsoCode = opLine.CurrencyIsoCode,
                                                   Atlassian_License_Type__c = opLine.Atlassian_License_Type__c,
                                                   isLicence__c = isLicense,
                                                   PricebookId__c = opLine.pricebook_ID__c,
                                                   PricebookEntryId__c = opLine.PricebookEntryId,
                                                   CodeUseLineId__c = opLine.id);
                            lstOfAssToInsert.add(ass1); 
                        }
                    }
                }
                
            }
        }

        insert lstOfAssToInsert;
        update lstOfAssToUpdate;
        
        // Check for created Assets and populate the oppLine.CodeUseAssetId__c field with Asset id
        
        lstOfInsertedAssets = [SELECT id,CodeUseLineId__c FROM Asset WHERE CodeUseLineId__c IN:lstOfOppLineIds];
        List<OpportunityLineItem> lstOfUpdateOppLine = new List<OpportunityLineItem>();
        
        for (Asset ass: lstOfInsertedAssets){
            if (ass.CodeUseLineId__c !=null){
                if(mpOfLineItems != null && mpOfLineItems.size() > 0 && mpOfLineItems.containsKey(ass.CodeUseLineId__c)){
                    OpportunityLineItem oppLine = mpOfLineItems.get(ass.CodeUseLineId__c);
                    if(oppLine.CodeUseAssetId__c == null){
                        oppLine.CodeUseAssetId__c = ass.Id;
                        lstOfUpdateOppLine.add(oppLine);
                    }
                }
            }
        }
        
        update lstOfUpdateOppLine;
        
        
        System.debug('Lst of Updated Opp Line:' + lstOfUpdateOppLine);
        
        System.debug('AccIds:' + lstOfOppAccIds);
        //List<Asset> newAss = [SELECT AccountId,Product2Id,Price,InstallDate,UsageEndDate,PurchaseDate,CurrencyIsoCode, Atlassian_License_Type__c,isLicence__c,PricebookId__c FROM Asset WHERE AccountId IN: lstOfOppAccIds];
        //for (Asset ass: newAss){
        //    System.debug('Asset:' + ass);
        //}
        //System.debug('Assets:' + newAss);
        
        
        
    }
    
    */
}