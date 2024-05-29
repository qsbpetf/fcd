/* 
* @author Alan Abishev - Ceterna LTD
* @createddate 21/04/2017
* @edited 02/03/2018
*/


/*=============================================================================
//
//    Batch for creating Opportunities and OppLines from Assets when EndUsageDate == today + 90 days
//    
//    Example 1: 1 Asset creates 1 Opp and 1 Opp line; 
//    Example 2: If 2 Assets have the same values in 3 fields below -> 2 Assets create 1 Opp and 2 OppLines
//    Assets are grouped by an opportunity if UsageEndDate AND AccountId AND PricebookId are the same
//    A combination of them is a string field on Opportunity called CombinationString__c
//    
//=============================================================================*/



global class batchOppFromAssets implements Database.Batchable<sObject>,Database.AllowsCallouts,Database.Stateful{
    /* This code is not being used and prevents any deployment as it is not properly covered by a test class
     * Therefore, its content is being commented out
     * For future developer working on this again, you will need to correct the test class batchOppFromAssetsTest
     */
    global final String query;
    global final Date ninetyDays;
    global final Date testDate;
    public String oppOwnerId = System.Label.AssetRenewalOwner;
    
    global batchOppFromAssets(){
        ninetyDays = system.today().addDays(90);
        testDate = date.newInstance(2019, 05, 22);
        
        query = 'SELECT id,name,AccountId,CurrencyIsoCode,Quantity,Product2Id, Product2.Family, Atlassian_License_Type__c,PricebookId__c,UsageEndDate,Price,PricebookEntryId__c,Account_Name__c,prodName__c,SerialNumber,ContactId FROM Asset WHERE UsageEndDate=:ninetyDays';
        //query = 'SELECT id,name,AccountId,CurrencyIsoCode,Quantity,Product2Id,Atlassian_License_Type__c,PricebookId__c,UsageEndDate,Price,PricebookEntryId__c,Account_Name__c,prodName__c,SerialNumber,ContactId FROM Asset WHERE UsageEndDate=:testDate';
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<Asset> scope){
        /**
        List<Opportunity> lstOfOpps = new List<Opportunity>();
        List<OpportunityLineItem> lstOfOppLineItems = new List<OpportunityLineItem>();
        List<Opportunity> lstOfInsertedOpps = new List<Opportunity>();
        List<String> lstOfCombStrings = new List<String>();
        Map<String,Opportunity> mpOfOpps = new Map<String,Opportunity>();
         String stg;
         
        if (Label.OppStage==null || Label.OppStage==''){
            stg = 'Propose - Auto Generated [DO NOT USE]';
        }else{
            stg=Label.OppStage;
        }
        
        List<Asset> lstOfAss = new List<Asset>();
        Map<String,List<Asset>> mpOfAsset = new Map<String,List<Asset>>();
        
        for (Asset ass: scope){
            
            String combStr = ass.AccountId + ass.PricebookId__c + String.valueOf(ass.UsageEndDate);
            
            if(mpOfAsset.isEmpty() || (!mpOfAsset.isEmpty() && !mpOfAsset.containsKey(combStr))){
                mpOfAsset.put(combStr, new List<Asset>{ass});
            }else{
                mpOfAsset.get(combStr).add(ass);
            }
            System.debug(mpOfAsset);
            
        }  
        
        
        // Creating Opportunities based on Assets
        for (String combStringKey: mpOfAsset.keySet()){
            String oppName;
            
                  
            List<Asset> lstOfAsses= mpOfAsset.get(combStringKey);
            System.debug('SIZE: ' + lstOfAsses.size() + ' ' + lstOfAsses );
            oppName = lstOfAsses[0].Account_Name__c;
            for(Asset ass:lstOfAsses){
                oppName+= ' ' + ass.prodName__c;
            }
            if(oppName.length()>80) oppName = oppName.substring(0,79);
            
            
            Opportunity opp = new Opportunity(
                ownerId = oppOwnerId,
                Renewal_Opportunity__c = true,
                Name = oppName,
                AccountId = lstOfAsses[0].AccountId,
                StageName = stg,
                CloseDate = lstOfAsses[0].UsageEndDate,
                CurrencyIsoCode = lstOfAsses[0].CurrencyIsoCode,
                CombinationString__c = combStringKey);
            lstOfOpps.add(opp);
            lstOfCombStrings.add(combStringKey);
         
            
            
        }
        System.debug('List of Opps to Insert:' + lstOfOpps);
        insert lstOfOpps;
        
        lstOfInsertedOpps = [SELECT id,name,CombinationString__c FROM Opportunity WHERE CombinationString__c IN: lstOfCombStrings AND CreatedDate=today];
        
        System.debug('List of Inserted Opportunities:' + lstOfInsertedOpps.size());
        
        //  ---OppLine creation---
        
        if (!lstOfInsertedOpps.isEmpty()){
            for(Opportunity opp : lstOfInsertedOpps){
                if(mpOfOpps.isEmpty() || (!mpOfOpps.isEmpty() && !mpOfOpps.containsKey(opp.CombinationString__c))){
                    mpOfOpps.put(opp.CombinationString__c, opp);
                }          
            }  
        }
        
        if(!mpOfOpps.isEmpty()){
            
           
            for (Asset ass: scope){
                //Add fields later
                
                String atlType;
                if(ass.Product2.Family=='Atlassian addons (non Marketplace)' || ass.Product2.Family=='Atlassian Data Center' 
                   || ass.Product2.Family=='Atlassian Marketplace' || ass.Product2.Family=='Atlassian - Server'){
                    if (ass.Atlassian_License_Type__c=='Marketplace New' ||ass.Atlassian_License_Type__c=='Marketplace Renewal' 
                        || ass.Atlassian_License_Type__c=='Co-Term New renewal' || ass.Atlassian_License_Type__c=='Co-Term CV renewal'
                        ||ass.Atlassian_License_Type__c=='New' ||ass.Atlassian_License_Type__c=='CV renewal' || ass.Atlassian_License_Type__c=='New Renewal')
                        atlType= 'CV Renewal (Atlassian License)';
                }
                if(ass.Product2.Family=='Atlassian Cloud' || ass.Product2.Family=='Atlassian - Services' || ass.Product2.Family=='CV Products' || ass.Product2.Family=='OtherVendorProduct' || ass.Product2.Family=='X Squad Licenses'){
                    if (ass.Atlassian_License_Type__c=='New' ||ass.Atlassian_License_Type__c=='Manual (Upgrades/cloud/Xsquad)')
                        atlType= 'Manual (Upgrades/ATCloud/XSquad)';
                }
                if(ass.Product2.Family=='Hosting (CV)' || ass.Product2.Family=='Support (CV)'){
                    if (ass.Atlassian_License_Type__c=='Service (Support/Host/PS)')
                        atlType= 'Service (Supp/Host/PS)';
                }

                Decimal quant= ass.Quantity!=null ? ass.Quantity : 1;
                String combStr = ass.AccountId + ass.PricebookId__c + String.valueOf(ass.UsageEndDate);
                OpportunityLineItem oppLine = new OpportunityLineItem(
                    OpportunityId = mpOfOpps.get(combStr).id,
                    SEN_Technical_Contact__c = ass.ContactId,
                    Quantity = quant,
                    CreatedFromAssetId__c = ass.id,
                    Atlassian_License_Type__c = atlType,
                    SEN__c = ass.SerialNumber,
                    PricebookEntryId = ass.PricebookEntryId__c,
                    TotalPrice = ass.Price);
                  
                lstOfOppLineItems.add(oppLine);
            }
        }
        
        System.debug('List of OppLineItems:' + lstOfOppLineItems.size() + ' ' + lstOfOppLineItems);
        insert lstOfOppLineItems;      
*/
    }
    
    global void finish(Database.BatchableContext BC){
      /*  // Get the ID of the AsyncApexJob representing this batch job
        // from Database.BatchableContext.
        
        // Query the AsyncApexJob object to retrieve the current job's information.
        AsyncApexJob a = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
                          TotalJobItems, CreatedBy.Email
                          FROM AsyncApexJob WHERE Id =
                          :BC.getJobId()];
        
        System.debug(a);
        
        // Send an email to the Apex job's submitter notifying of job completion.
        /*Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
String[] toAddresses = new String[] {'alanbaraban1@gmail.com'};
mail.setToAddresses(toAddresses);
mail.setSubject('Apex Batch ' + a.Status);
mail.setPlainTextBody
('Batches: ' + a.TotalJobItems +
', Batch Failures: '+ a.NumberOfErrors + ', Number of Objects processed: ' + count + ' Names: ' + values + ', Exist: ' + countExist + ' Names: ' + valuesExist+ ', Edited: ' + countEdited + ' Names: ' + valuesEdited +', Internal Errors: ' + countError + ' Names: ' + valuesError );
Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });*/
    }
}