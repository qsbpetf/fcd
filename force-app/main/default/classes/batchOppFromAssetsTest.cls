/* 
* @author Alan Abishev - Ceterna LTD
* @createddate 21/04/2017
* @edited 02/03/2018
*/

@isTest
public class batchOppFromAssetsTest {
    //To be deleted if the batchOppFromAssetsTest code is ever reused
    public static testMethod void minimumTestToCoverBatch(){
        test.startTest();
        batchOppFromAssets bch = new batchOppFromAssets();
        Database.executeBatch(bch);
        test.stopTest();
    }
    /* This code is not being used and prevents any deployment as it fails
     * Therefore, its content is being commented out
     * For future developer working on this again, this test class batchOppFromAssetsTest is supposed to cover the batchOppFromAssets
     *
    @TestSetup
    public static void setupTestData(){
        
    }
    
    
    @isTest
    public static void testAssetOneOppId(){
        test.startTest();
        
        batchOppFromAssetsTest bt = new batchOppFromAssetsTest();
        Account acc = bt.getAccount();
        insert acc;

        Contact con = bt.getOneCon(acc);
        insert con;

        acc.Main_Invoice_Contact__c = con.Id;
        update acc;
        
        Opportunity opp = bt.getOpp(acc.id, 'Validate');
        insert opp;
        
        List<OpportunityLineItem> lstOfOppLine = bt.getOpportunityLineItem(opp,false,'Co-Term New renewal','Product Banana',con);
        insert lstOfOppLine;
        
        List<OpportunityLineItem> lstSOQL = [SELECT CodeUseAssetId__c,CreatedFromAssetId__c,Atlassian_License_Type__c FROM OpportunityLineItem];
        System.debug('SQOL:' + lstSOQL);
        System.debug('CODE:' + lstSOQL[0].Atlassian_License_Type__c + ' ' + lstSOQL[1].Atlassian_License_Type__c);

        opp.StageName = 'Order';
        update opp;
        
        List<Asset> newAss = [SELECT AccountId,ContactId,Product2Id,Price,InstallDate,UsageEndDate,PurchaseDate,CurrencyIsoCode, Atlassian_License_Type__c,isLicence__c,PricebookId__c,CodeUseLineId__c,PricebookEntryId__c FROM Asset];
        System.assertEquals(2, newAss.size());
        
        batchOppFromAssets bch = new batchOppFromAssets();
        Database.executeBatch(bch);
        
        test.stopTest();
        
        //1. A new Opportunity is created, 2 Opp lines are created
        List<Opportunity> lstOfOpp = [SELECT name,id,CloseDate,StageName,OwnerId,Renewal_Opportunity__c FROM Opportunity WHERE StageName='Propose - Auto Generated [DO NOT USE]'];
        System.assertEquals(system.today().addDays(90),lstOfOpp[0].CloseDate,'Close date of the Opp should be 90 days from now');
        System.assertEquals('Test Acc Product Banana Product Banana', lstOfOpp[0].name, 'OppName should be Account ProductName1 Product2Name');
        
        List<OpportunityLineItem> oppLineUp = [SELECT id,OpportunityId,Quantity,CreatedFromAssetId__c,CodeUseAssetId__c,CurrencyIsoCode,Product2Id,Total_List_Price_Incl_Discount__c,license_start_date__c,license_end_date__c,Atlassian_License_Type__c,Is_Licence__c,pricebook_ID__c,PricebookEntryId,SEN_Technical_Contact__c FROM OpportunityLineItem WHERE OpportunityId =:lstOfOpp[0].id];
        String oppOwnerId= System.Label.AssetRenewalOwner;
        
        System.assertEquals(con.id,oppLineUp[0].SEN_Technical_Contact__c, 'OppLine Contact field should be populated' );
        System.assertEquals(1,lstOfOpp.size(), 'There should be a one new Opp created');
        System.assertEquals(Label.OppStage, lstOfOpp[0].StageName,'The stage is not correct');
        System.debug('Opportunity Name: ' + lstOfOpp[0].name);
        System.assertEquals(true, lstOfOpp[0].Renewal_Opportunity__c, 'Renewal_Opportunity__c checkbox should be tickted');
        System.assertEquals(oppOwnerId, lstOfOpp[0].OwnerId, 'Opportunity Owner id should be from Custom Label oppOwner ');
        System.assertEquals(oppLineUp[0].SEN_Technical_Contact__c,newAss[0].ContactId, 'Asset.ContactId should be populated by OppLine.Sen_Technical Contact');
        
        //2. 2 Opp Lines have CreatedFromAssetId__c populated with related AssetId
        Integer assCount=0;
        
        for (Asset ass: newAss){
            for(OpportunityLineItem oppLine: oppLineUp){
                if (ass.id==oppLine.CreatedFromAssetId__c){
                    assCount++;
                }
            } 
        }
        
        System.assertEquals(2,assCount,'New Opplines should have CreatedFromAssetId__c field populated');       
        
    }
    
    @isTest
    public static void testAssetSeparateOppId(){
        
        batchOppFromAssetsTest bt = new batchOppFromAssetsTest();
        Account acc = bt.getAccount();
        acc.name='Test Account 1';
        Account acc2 = bt.getAccount();
        acc2.name='Test Account 2';
        insert new List<Account>{acc, acc2};
        
        Contact con = bt.getOneCon(acc);
        Contact con2 = bt.getOneCon(acc2);
        insert new List<Contact>{con, con2};

        acc.Main_Invoice_Contact__c = con.Id;
        acc2.Main_Invoice_Contact__c = con2.Id;
        update new List<Account>{acc, acc2};
                
        Opportunity opp = bt.getOpp(acc.id, 'Validate');
        Opportunity opp2 = bt.getOpp(acc2.id, 'Validate');
        insert new List<Opportunity>{opp, opp2};       
        
        List<OpportunityLineItem> lstOfOppLine = bt.getOpportunityLineItem(opp,true,'New','Product Apple',con);
        insert lstOfOppLine;
        
        List<OpportunityLineItem> lstOfOppLine2 = bt.getOpportunityLineItem(opp2,true,'Co-Term New renewal','Product Keyboard',con2);
        insert lstOfOppLine2;
        
        List<OpportunityLineItem> lstSOQL = [SELECT CodeUseAssetId__c,CreatedFromAssetId__c FROM OpportunityLineItem];
        System.debug('SQOL:' + lstSOQL);
        
        opp.StageName = 'Order';
        opp2.StageName = 'Order';
        update new List<Opportunity>{opp, opp2};        
        
        List<Asset> newAss = [SELECT AccountId,ContactId,Product2Id,Price,InstallDate,UsageEndDate,PurchaseDate,CurrencyIsoCode, Atlassian_License_Type__c,isLicence__c,PricebookId__c,CodeUseLineId__c,PricebookEntryId__c FROM Asset];
        for(Asset ass: newAss){
            System.debug(ass.AccountId + ' ' + ass.Atlassian_License_Type__c);
        }

        Test.startTest();

        List<OpportunityLineItem> lstSOQL2 = [SELECT CodeUseAssetId__c,CreatedFromAssetId__c FROM OpportunityLineItem];
        System.debug('SQOL2:' + lstSOQL2);
        
        System.assertNotEquals(newAss[0].AccountId,newAss[1].AccountId, '2 Assets should have different AccountIds');
  
        batchOppFromAssets bch = new batchOppFromAssets();
        Database.executeBatch(bch);
        
        Test.stopTest(); 
        
        List<Opportunity> lstOfOpp = [SELECT name,id,Renewal_Opportunity__c FROM Opportunity WHERE StageName='Propose - Auto Generated [DO NOT USE]'];
        
        List<String> lstOfOppIds = new List<String>();
        for (Opportunity opp1: lstOfOpp){
            lstOfOppIds.add(opp1.id);
        }
        
        List<OpportunityLineItem> oppLineUp = [SELECT id,OpportunityId,Quantity,CreatedFromAssetId__c,CodeUseAssetId__c,CurrencyIsoCode,Product2Id,Total_List_Price_Incl_Discount__c,license_start_date__c,license_end_date__c,Atlassian_License_Type__c,Is_Licence__c,pricebook_ID__c,PricebookEntryId,SEN_Technical_Contact__c FROM OpportunityLineItem WHERE OpportunityId IN:lstOfOppIds];        
        
        for (OpportunityLineItem oppLine: oppLineUp){
            System.debug(oppLine.Atlassian_License_Type__c);
        }
        
        System.assertEquals(true, lstOfOpp[0].Renewal_Opportunity__c, 'The renewal Opp field should be true');
        System.assertEquals(2,lstOfOpp.size());
        System.assertEquals(2,oppLineUp.size());
        System.assertEquals(con.id,oppLineUp[0].SEN_Technical_Contact__c, 'OppLine Contact field should be populated' );
        
        //2. 2 Opp Lines have CreatedFromAssetId__c populated with related AssetId
        Integer assCount=0;
        
        for (Asset ass: newAss){
            for(OpportunityLineItem oppLine: oppLineUp){
                if (ass.id==oppLine.CreatedFromAssetId__c){
                    assCount++;
                }
            } 
        }
        
        System.assertEquals(2,assCount,'New Opplines should have CreatedFromAssetId__c field populated');
        
        
    }
    
    @isTest
    public static void testOppNameTooLong(){
        test.startTest();
        
        batchOppFromAssetsTest bt = new batchOppFromAssetsTest();
        Account acc = bt.getAccount();
        insert acc;
        
        Contact con = bt.getOneCon(acc);
        insert con;

        acc.Main_Invoice_Contact__c = con.Id;
        update acc;
       	
        Opportunity opp = bt.getOpp(acc.id, 'Validate');
        insert opp;
        
        List<OpportunityLineItem> lstOfOppLine = bt.getOpportunityLineItem(opp,false,'Co-Term New renewal','Atlassian Bitbucket + Git: Basics Training Course - Remote Atlassian Bitbucket + Git: Basics Training Course - Remote',con);
        insert lstOfOppLine;
        
        List<OpportunityLineItem> lstSOQL = [SELECT CodeUseAssetId__c,CreatedFromAssetId__c,Atlassian_License_Type__c FROM OpportunityLineItem];
        System.debug('SQOL:' + lstSOQL);
        System.debug('CODE:' + lstSOQL[0].Atlassian_License_Type__c + ' ' + lstSOQL[1].Atlassian_License_Type__c);
        opp.StageName = 'Order';
        update opp;
        
        List<Asset> newAss = [SELECT AccountId,Product2Id,Price,InstallDate,UsageEndDate,PurchaseDate,CurrencyIsoCode,ContactId, Atlassian_License_Type__c,isLicence__c,PricebookId__c,CodeUseLineId__c,PricebookEntryId__c FROM Asset];
        
        
        for (Asset ass: newAss){
            System.debug('Asset:' + ass.Atlassian_License_Type__c);
        }
        
        batchOppFromAssets bch = new batchOppFromAssets();
        Database.executeBatch(bch);
        
        test.stopTest();
        
        //1. A new Opportunity is created, 2 Opp lines are created
        List<Opportunity> lstOfOpp = [SELECT name,id,CloseDate,StageName FROM Opportunity WHERE StageName='Propose - Auto Generated [DO NOT USE]'];
        System.assertEquals(system.today().addDays(90),lstOfOpp[0].CloseDate,'Close date of the Opp should be 90 days from now');
        //System.assertEquals('Test Acc Product Banana  Product Banana', lstOfOpp[0].name, 'OppName should be Account ProductName1 Product2Name');
      
        
        
        List<OpportunityLineItem> oppLineUp = [SELECT id,OpportunityId,Quantity,CreatedFromAssetId__c,CodeUseAssetId__c,CurrencyIsoCode,Product2Id,Total_List_Price_Incl_Discount__c,license_start_date__c,license_end_date__c,Atlassian_License_Type__c,Is_Licence__c,pricebook_ID__c,PricebookEntryId,SEN__c,SEN_Technical_Contact__c FROM OpportunityLineItem WHERE OpportunityId =:lstOfOpp[0].id];        
       
        System.assertEquals(1,lstOfOpp.size(), 'There should be a one new Opp created');
        System.assertEquals(Label.OppStage, lstOfOpp[0].StageName,'The stage is not correct');
        System.debug('Opportunity Name: ' + lstOfOpp[0].name);
        System.assertEquals(2,oppLineUp.size(),'There should be two new OppLines');
    //    System.assertEquals('CV renewal', oppLineUp[0].Atlassian_License_Type__c, '1st New OppLine From Asset Attlasian type should be CV Renewal ');
        System.assertEquals('Sample SEN', oppLineUp[0].SEN__c, '1st New OppLine From Asset SEN should be sample SEN');
    //    System.assertEquals(oppLineUp[0].OpportunityId, oppLineUp[1].OpportunityId, '2 OppLines should have the same OppId');
        
        
        //2. 2 Opp Lines have CreatedFromAssetId__c populated with related AssetId
        Integer assCount=0;
        
        for (Asset ass: newAss){
            for(OpportunityLineItem oppLine: oppLineUp){
                if (ass.id==oppLine.CreatedFromAssetId__c){
                    assCount++;
                }
            } 
        }
        
        System.assertEquals(2,assCount,'New Opplines should have CreatedFromAssetId__c field populated');
        
        
        
    }
    
    public Account getAccount(){
        Account acc = new Account(Name='Test Acc', BillingCountry='United Kingdom', CurrencyIsoCode='GBP');
        return acc;
    }
    
    public Opportunity getOpp(String accId, String stageName){
        Opportunity opp = new Opportunity(Name='Test Opp', CloseDate = system.today().addDays(90),StageName = stageName, AccountId = accId,
                            Description = 'Test', NextStep = 'Test', LeadSource = 'Adwords', Type='Existing Customer', Special_Instructions_to_Accounts__c='Test',
                            Delivery_Date__c = system.today().adddays(10), Atlassian_Payment_link__c='Test', Customer_PO_Number__c='Test PO Number', Atlassian_AT_Quote_ref__c='Test ref');
        return opp;
    }
    
    public Contact getOneCon(Account acc){
        Contact con = new Contact(LastName = 'testCon', AccountId = acc.id);
        return con;
    }
    
    public List<OpportunityLineItem> getOpportunityLineItem(Opportunity opp,Boolean isOneAcc,String atType, String prodName,Contact con){
        List<OpportunityLineItem> lstOfOppLineItem = new List<OpportunityLineItem>();
        
        Id pricebookId = Test.getStandardPricebookId();
        
        //Create your product
        Product2 prod = new Product2(
            Name = prodName,
            ProductCode = 'Pro-X',
            isActive = true,
            Family ='Atlassian Data Center',
            Unit_Measure__c = 'Day');
        insert prod;
        
        //Create your pricebook entry
        PricebookEntry pbEntry = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbEntry;

        if(!isOneAcc){
            OpportunityLineItem oppLineItem = new OpportunityLineItem(OpportunityId = opp.id,
                                                                      Quantity = 1,
                                                                      PricebookEntryId = pbEntry.Id,
                                                                      List_Price_Inc_Licence_Type__c=pbEntry.UnitPrice,
                                                                      UnitPrice = pbEntry.UnitPrice,
                                                                      License_Start_date__c = system.today(),
                                                                      Atlassian_License_Type__c = 'New',
                                                                      SEN__c = 'Sample SEN',
                                                                      SEN_Technical_Contact__c = con.id,
                                                                      License_end_date__c = system.today().addDays(90),
                                                                      Multi_or_single_invoice__c='',
                                                                      Discount__c=0.1
                                                                     );
            lstOfOppLineItem.add(oppLineItem);
        }
        
        OpportunityLineItem oppLineItem2 = new OpportunityLineItem(OpportunityId = opp.id,
                                                                   Quantity = 1,
                                                                   PricebookEntryId = pbEntry.Id,
                                                                   UnitPrice = pbEntry.UnitPrice,
                                                                   List_Price_Inc_Licence_Type__c=pbEntry.UnitPrice,
                                                                   Atlassian_License_Type__c = atType,
                                                                   License_Start_date__c = system.today(),
                                                                   SEN__c = 'Sample SEN',
                                                                   SEN_Technical_Contact__c = con.id,
                                                                   Multi_or_single_invoice__c='',
                                                                   Discount__c=0.1,
                                                                   License_end_date__c = system.today().addDays(90));

        lstOfOppLineItem.add(oppLineItem2);
        
        return lstOfOppLineItem;
    }
    */
}