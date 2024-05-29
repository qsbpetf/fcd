/* 
* @author Alan Abishev - Ceterna LTD
* @createddate 21/04/2017
* @edited 14/08/2017
*/

@isTest
public class triggerCreateAssetsHandlerTest {
    /*This code is not being used and prevents any deployment as it is not properly covered by a test class
     * Therefore, its content is being commented out
     * For future developer working on this again, this test class should cover the triggerCreateAssetsHandler class and the triggerCreateAssets trigger
     
    // 1.Test a trigger when StageName is not Order, nothing should happen
    @isTest
    public static void testOppStageNameNotOrder(){
        triggerCreateAssetsHandlerTest tst = new triggerCreateAssetsHandlerTest();
        
        Account acc = tst.getOneAccount();
        insert acc;
        Opportunity opp = tst.getOneOpp(acc.id);
        insert opp;
        Contact con = tst.getOneCon(acc);
        insert con;
        
        OpportunityLineItem oppLine = tst.getOneOppLine(opp,true,con);
        insert oppLine;
        
        opp.StageName = 'Propose - Auto Generated [DO NOT USE]';
        update opp;
        
        List<Asset> lstOfAss = new List<Asset>();
        lstofAss = [SELECT id from Asset];
        System.assertEquals(0, lstOfAss.size(), 'num of Assets should be 0');
        
    }
    
    // 2.Test a trigger when StageName is Order, should create an Asset and fill in 1 field
    @isTest
    public static void testOppStageNameEqualsOrder(){
        triggerCreateAssetsHandlerTest tst = new triggerCreateAssetsHandlerTest();
        
        Account acc = tst.getOneAccount();
        insert acc;
        Contact con = tst.getOneCon(acc);
        insert con;
        acc.Main_Invoice_Contact__c = con.Id;
        update acc;
        
        Opportunity opp = tst.getOneOpp(acc.id);
        insert opp;
        
        OpportunityLineItem oppLine = tst.getOneOppLine(opp,true,con);
        insert oppLine;
        
        
        opp.StageName = 'Order';
        update opp;
        
        List<Asset> lstOfAss = new List<Asset>();
        lstofAss = [SELECT id,Accountid,Quantity,Product2Id,Price,InstallDate,UsageEndDate,PurchaseDate,CurrencyIsoCode,Atlassian_License_Type__c,isLicence__c,PricebookId__c,PricebookEntryId__c,CodeUseLineId__c,SerialNumber,ContactId from Asset];
        
        OpportunityLineItem oppLineUp = [SELECT id,Quantity,CreatedFromAssetId__c,CodeUseAssetId__c,CurrencyIsoCode,Product2Id,Total_List_Price_Incl_Discount__c,license_start_date__c,license_end_date__c,Atlassian_License_Type__c,Is_Licence__c,pricebook_ID__c,PricebookEntryId,SEN_Technical_Contact__c FROM OpportunityLineItem WHERE id=:oppLine.id LIMIT 1];        
        
        
        System.assertEquals(1, lstOfAss.size(), 'num of Assets should be 1');
        System.assertEquals(null,oppLineUp.CreatedFromAssetId__c, 'CreateFromAsset field should be null, as its not created from an asset');
        System.assertEquals(lstOfAss[0].id, oppLineUp.CodeUseAssetId__c, 'CodeUseAssetId field is not filled in');
        System.assertEquals(con.id,oppLineUp.SEN_Technical_Contact__c, 'OppLine Contact field should be populated' );
        
        System.assertEquals(acc.id,lstOfAss[0].Accountid,'Asset Accountid is different than OpplIneItem');
        System.assertEquals(oppLineUp.Quantity,lstOfAss[0].Quantity,'Asset Quantity is different than OpplIneItem');
        System.assertEquals(oppLineUp.Product2Id,lstOfAss[0].Product2Id,'Asset Product2Id is different than OpplIneItem');
        System.assertEquals(oppLineUp.Total_List_Price_Incl_Discount__c,lstOfAss[0].Price,'Asset Price is different than OpplIneItem');
        System.assertEquals(oppLineUp.license_start_date__c,lstOfAss[0].InstallDate,'Asset Install date is different than OpplIneItem');
        System.assertEquals(oppLineUp.license_end_date__c,lstOfAss[0].usageEndDate,'Asset UsageEndDate is different than OpplIneItem');
        System.assertEquals(date.today(),lstOfAss[0].PurchaseDate,'Asset Purchasedate is not today');
        System.assertEquals(oppLineUp.CurrencyIsoCode,lstOfAss[0].CurrencyIsoCode,'Asset CurrencyIsoCode is different than OpplIneItem');
        System.assertEquals(oppLineUp.Atlassian_License_Type__c,lstOfAss[0].Atlassian_License_Type__c,'Asset Atlassian_License_Type__c is different than OpplIneItem');
        System.assertEquals(oppLineUp.Is_Licence__c,lstOfAss[0].IsLicence__c,'Asset Is_Licence__c is different than OpplineItem');
        System.assertEquals(oppLineUp.pricebook_ID__c,lstOfAss[0].PricebookId__c,'Asset PriceBookId is different than OpplineItem');
        System.assertEquals(oppLineUp.PricebookEntryId,lstOfAss[0].PricebookEntryId__c,'Asset PricebookEntryId is different than OpplIneItem');
        System.assertEquals(oppLineUp.SEN_Technical_Contact__c,lstOfAss[0].ContactId, 'Asset.ContactId should be populated by OppLine.Sen_Technical Contact');
        
        
        
        // 2.5.Test a trigger when StageName is Order, but OppLine CodeUseAssetId field is not null
        
        opp.StageName = 'Order';
        opp.TotalOpportunityQuantity = 1.2;
        update opp;
        
        List<Asset> lstOfAssUp = new List<Asset>();
        lstofAssUp = [SELECT id from Asset];
        
        System.assertEquals(1, lstOfAss.size(), 'num of new Assets should be 1');
        
        
    }
    
    // 3.Test a trigger when StageName is Order, should create an Asset and fill in 1 field, isLicence==false,enddate=null
    @isTest
    public static void testLicenceFalse(){
        triggerCreateAssetsHandlerTest tst = new triggerCreateAssetsHandlerTest();
        
        Account acc = tst.getOneAccount();
        insert acc;
        Contact con = tst.getOneCon(acc);
        insert con;
        acc.Main_Invoice_Contact__c = con.Id;
        update acc;
        
        Opportunity opp = tst.getOneOpp(acc.id);
        insert opp;
        
        OpportunityLineItem oppLine = tst.getOneOppLine(opp,false,con);
        oppLine.License_Start_date__c =null;
        oppLine.Non_Licence_End_Date__c=null; 
        oppLine.Renewal__c='Renewal';
        insert oppLine;
        
        OpportunityLineItem oppLine1 = tst.getOneOppLine(opp,true,con);
        insert oppLine1;
        
        opp.StageName = 'Order';
        update opp;
        
        List<Asset> lstOfAss = new List<Asset>();
        lstofAss = [SELECT id,Accountid,Quantity,Product2Id,Price,InstallDate,UsageEndDate,PurchaseDate,CurrencyIsoCode,Atlassian_License_Type__c,isLicence__c,PricebookId__c,PricebookEntryId__c,CodeUseLineId__c,SerialNumber,ContactId from Asset];
        
        OpportunityLineItem oppLineUp = [SELECT id,Quantity,CreatedFromAssetId__c,CodeUseAssetId__c,CurrencyIsoCode,Product2Id,Total_List_Price_Incl_Discount__c,license_start_date__c,license_end_date__c,Atlassian_License_Type__c,Is_Licence__c,pricebook_ID__c,PricebookEntryId,SEN__c,SEN_Technical_Contact__c  FROM OpportunityLineItem WHERE id=:oppLine.id LIMIT 1];        
        
        // The most important fields are IsLicence, Usage enddate and Installation_date
        
        System.assertEquals(2, lstOfAss.size(), 'num of Assets should be 1');
        System.assertEquals(null,oppLineUp.CreatedFromAssetId__c, 'CreateFromAsset field should be null, as its not created from an asset');
        System.assertEquals(lstOfAss[0].id, oppLineUp.CodeUseAssetId__c, 'CodeUseAssetId field is not filled in');
        System.assertEquals(con.id,oppLineUp.SEN_Technical_Contact__c, 'OppLine Contact field should be populated' );
        
        System.assertEquals(acc.id,lstOfAss[0].Accountid,'Asset Accountid is different than OpplIneItem');
        System.assertEquals(oppLineUp.Quantity,lstOfAss[0].Quantity,'Asset Quantity is different than OpplIneItem');
        System.assertEquals(oppLineUp.Product2Id,lstOfAss[0].Product2Id,'Asset Product2Id is different than OpplIneItem');
        System.assertEquals(oppLineUp.Total_List_Price_Incl_Discount__c,lstOfAss[0].Price,'Asset Price is different than OpplIneItem');
        System.assertEquals(system.today(),lstOfAss[0].InstallDate,'Asset Install date is different than OpplIneItem');
        System.assertEquals(oppLineUp.license_end_date__c,null,'Asset UsageEndDate is different than OpplIneItem');
        System.assertEquals(date.today(),lstOfAss[0].PurchaseDate,'Asset Purchasedate is not today');
        System.assertEquals(oppLineUp.CurrencyIsoCode,lstOfAss[0].CurrencyIsoCode,'Asset CurrencyIsoCode is different than OpplIneItem');
        System.assertEquals(oppLineUp.Atlassian_License_Type__c,lstOfAss[0].Atlassian_License_Type__c,'Asset Atlassian_License_Type__c is different than OpplIneItem');
        System.assertEquals(oppLineUp.Is_Licence__c,lstOfAss[0].IsLicence__c,'Asset Is_Licence__c is different than OpplineItem');
        System.assertEquals(oppLineUp.pricebook_ID__c,lstOfAss[0].PricebookId__c,'Asset PriceBookId is different than OpplineItem');
        System.assertEquals(oppLineUp.PricebookEntryId,lstOfAss[0].PricebookEntryId__c,'Asset PricebookEntryId is different than OpplIneItem');
        System.assertEquals(oppLineUp.SEN__c, lstOfAss[0].SerialNumber, 'Asset SerialNumber should be populated from OpportunityLine SEN__c');
        System.assertEquals(oppLineUp.SEN_Technical_Contact__c,lstOfAss[0].ContactId, 'Asset.ContactId should be populated by OppLine.Sen_Technical Contact');
        
        
        
    }
    
    // 4.Test a trigger when StageName is Order, Create an OppLine from an Asset, update Asset
    @isTest
    public static void testUpdateRelatedAsset(){
        triggerCreateAssetsHandlerTest tst = new triggerCreateAssetsHandlerTest();
        
        Test.startTest();
        Account acc = tst.getOneAccount();
        insert acc;
        Contact con = tst.getOneCon(acc);
        insert con;
        acc.Main_Invoice_Contact__c = con.Id;
        update acc;
        
        Opportunity opp = tst.getOneOpp(acc.id);
        insert opp;
        
        OpportunityLineItem oppLine = tst.getOneOppLine(opp,true,con);
        insert oppLine;
        
        opp.StageName = 'Order';
        update opp;
        
        List<Asset> lstOfAss = new List<Asset>();
        lstofAss = [SELECT id,Accountid,Quantity,Product2Id,Price,InstallDate,UsageEndDate,PurchaseDate,CurrencyIsoCode,Atlassian_License_Type__c,isLicence__c,PricebookId__c,PricebookEntryId__c,CodeUseLineId__c,ContactId from Asset];
        
        // 2.5.Test a trigger when StageName is Order, but OppLine CodeUseAssetId field is not null

		//opp.StageName = 'Order';
		//opp.TotalOpportunityQuantity = 1.2;
		//update opp;
        Test.stopTest();
        
        List<Asset> lstOfAssUp = new List<Asset>();
        lstofAssUp = [SELECT id,ContactId from Asset];
        
        System.assertEquals(1, lstOfAss.size(), 'num of new Assets should be 1');
        
        
    }
    
    // 5.Test a trigger when StageName is Order, should create an Asset and fill in 1 field, isLicence==false,Non Licence end date is not null
    @isTest
    public static void testNonLicenceDate(){
        triggerCreateAssetsHandlerTest tst = new triggerCreateAssetsHandlerTest();
        
        Account acc = tst.getOneAccount();
        insert acc;
        Contact con = tst.getOneCon(acc);
        insert con;
        acc.Main_Invoice_Contact__c = con.Id;
        update acc;
        
        Opportunity opp = tst.getOneOpp(acc.id);
        insert opp;
        
        OpportunityLineItem oppLine = tst.getOneOppLine(opp,false,con);
        oppLine.Product_Familly__c = 'Training (cv)';
        oppLine.Non_Licence_End_Date__c = null;
        oppLine.Renewal__c='Renewal';
        insert oppLine;
        
        OpportunityLineItem oppLine1 = tst.getOneOppLine(opp,true,con);
        insert oppLine1;
        
        opp.StageName = 'Order';
        update opp;
        
        List<Asset> lstOfAss = new List<Asset>();
        lstofAss = [SELECT id,Accountid,Quantity,Product2Id,Price,InstallDate,UsageEndDate,PurchaseDate,CurrencyIsoCode,Atlassian_License_Type__c,isLicence__c,PricebookId__c,PricebookEntryId__c,CodeUseLineId__c,SerialNumber,ContactId from Asset];
        
        OpportunityLineItem oppLineUp = [SELECT id,Quantity,CreatedFromAssetId__c,CodeUseAssetId__c,Non_Licence_End_Date__c,CurrencyIsoCode,Product2Id,Total_List_Price_Incl_Discount__c,license_start_date__c,license_end_date__c,Atlassian_License_Type__c,Is_Licence__c,pricebook_ID__c,PricebookEntryId,SEN__c,SEN_Technical_Contact__c  FROM OpportunityLineItem WHERE id=:oppLine.id LIMIT 1];        
        
        // The most important fields are IsLicence, Usage enddate and Installation_date
        
        System.assertEquals(2, lstOfAss.size(), 'num of Assets should be 1');
        System.assertEquals(null,oppLineUp.CreatedFromAssetId__c, 'CreateFromAsset field should be null, as its not created from an asset');
        System.assertEquals(lstOfAss[0].id, oppLineUp.CodeUseAssetId__c, 'CodeUseAssetId field is not filled in');
        System.assertEquals(con.id,oppLineUp.SEN_Technical_Contact__c, 'OppLine Contact field should be populated' );
        
        
        System.assertEquals(acc.id,lstOfAss[0].Accountid,'Asset Accountid is different than OpplIneItem');
        System.assertEquals(oppLineUp.Quantity,lstOfAss[0].Quantity,'Asset Quantity is different than OpplIneItem');
        System.assertEquals(oppLineUp.Product2Id,lstOfAss[0].Product2Id,'Asset Product2Id is different than OpplIneItem');
        System.assertEquals(oppLineUp.Total_List_Price_Incl_Discount__c,lstOfAss[0].Price,'Asset Price is different than OpplIneItem');
        System.assertEquals(system.today(),lstOfAss[0].InstallDate,'Asset Install date is different than OpplIneItem');
        //   System.assertEquals(oppLineUp.Non_Licence_End_Date__c,system.today().addDays(85),'Asset UsageEndDate is different than OpplIneItem');
        System.assertEquals(date.today(),lstOfAss[0].PurchaseDate,'Asset Purchasedate is not today');
        System.assertEquals(oppLineUp.CurrencyIsoCode,lstOfAss[0].CurrencyIsoCode,'Asset CurrencyIsoCode is different than OpplIneItem');
        System.assertEquals(oppLineUp.Atlassian_License_Type__c,lstOfAss[0].Atlassian_License_Type__c,'Asset Atlassian_License_Type__c is different than OpplIneItem');
        System.assertEquals(oppLineUp.Is_Licence__c,lstOfAss[0].IsLicence__c,'Asset Is_Licence__c is different than OpplineItem');
        System.assertEquals(oppLineUp.pricebook_ID__c,lstOfAss[0].PricebookId__c,'Asset PriceBookId is different than OpplineItem');
        System.assertEquals(oppLineUp.PricebookEntryId,lstOfAss[0].PricebookEntryId__c,'Asset PricebookEntryId is different than OpplIneItem');
        System.assertEquals(oppLineUp.SEN__c, lstOfAss[0].SerialNumber, 'Asset SerialNumber should be populated from OpportunityLine SEN__c');
        System.assertEquals(oppLineUp.SEN_Technical_Contact__c,lstOfAss[0].ContactId, 'Asset.ContactId should be populated by OppLine.Sen_Technical Contact');
        
    }
    
    
    public Account getOneAccount(){
        Account acc = new Account(Name='test Account');
        acc.BillingCountry='United Kingdom'; 
        acc.CurrencyIsoCode='GBP';
        return acc;
    }
    
    public Opportunity getOneOpp(String accId){
        Opportunity opp = new Opportunity(Name='Test Opp', CloseDate = system.today().addDays(90),StageName = 'Validate', AccountId = accId,
                                          Description = 'Test', NextStep = 'Test', LeadSource = 'Adwords', Type='Existing Customer', Special_Instructions_to_Accounts__c='Test',
                                          Delivery_Date__c = system.today().adddays(10), Atlassian_Payment_link__c='Test', Customer_PO_Number__c='Test PO Number', Atlassian_AT_Quote_ref__c='Test ref');
        return opp;
        return opp;
    }
    
    public Contact getOneCon(Account acc){
        Contact con = new Contact(LastName = 'testCon', AccountId = acc.id);
        return con;
    }
    
    
    public OpportunityLineItem getOneOppLine(Opportunity opp,boolean isLicence,Contact con){
        
        Id pricebookId = Test.getStandardPricebookId();
        
        string fml;
        string atType;
        Date startDate;
        Date endDate;
        if (isLicence==true){
            fml = 'Atlassian Data Center';
            atType= 'New';
            startDate = system.today().addDays(1);
            endDate = system.today().addDays(90);
        }else{
            fml = 'Clearhub (CV)';
        }
        
        //Create your product
        Product2 prod = new Product2(
            Name = 'attName',
            ProductCode = 'attProdCode',
            isActive = true,
            Family = fml,
            Unit_Measure__c = ' 12 months'
            
        );
        insert prod;
        
        
        //Create your pricebook entry
        PricebookEntry pbEntry = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbEntry;
        
        OpportunityLineItem oppLineItem = new OpportunityLineItem(OpportunityId = opp.id,
                                                                  Quantity = 5,
                                                                  PricebookEntryId = pbEntry.Id,
                                                                  TotalPrice = pbEntry.UnitPrice,
                                                                  License_Start_date__c = startDate,
                                                                  License_end_date__c = endDate,
                                                                  Atlassian_License_Type__c = atType,
                                                                  SEN_Technical_Contact__c = con.id,
                                                                  Multi_or_single_invoice__c='',
                                                                  Discount__c=0.1);
        //System.debug('OppLine 191 :' + pbEntry.Product2Id);
        
        return oppLineItem;
    }
    
    public List<Account> getAccounts(integer i){
        
        List<Account> lstOfAcc = new List<Account>();
        for (integer n=1;n<i+1;n++){
            Account acc = new Account(Name='test '+ n);
            acc.BillingCountry = 'United Kingdom';
            acc.CurrencyIsoCode = 'GBP';
            lstOfAcc.add(acc);
        }
        
        return lstOfAcc;
    }
    
    public List<Opportunity> getOpportunity(List<Account> lstOfAcc){
        List<Opportunity> lstOfOpp = new List<Opportunity>();
        Date dateNinetyDays = system.today().addDays(90);
        Id pricebookId = Test.getStandardPricebookId();
        for (integer num=0;num<lstOfAcc.size();num++){
            Opportunity opp = new Opportunity(Name='test '+ num, AccountId = lstOfAcc[num].id,StageName = 'Propose',
                                              CloseDate=dateNinetyDays,Pricebook2Id = pricebookId, Description ='sample desription',
                                              NextStep='Sample Next Step',LeadSource = 'Digital',Type='MDF',Special_Instructions_to_Accounts__c = 'Sample Instruction',
                                              Delivery_Date__c = system.today().adddays(10));
            lstOfOpp.add(opp); 
        }
        
        
        return lstOfOpp;
    }
    
    public List<OpportunityLineItem> getOpportunityLineItem(List<Opportunity> lstOfOpp){
        List<OpportunityLineItem> lstOfOppLineItem = new List<OpportunityLineItem>();
        
        Id pricebookId = Test.getStandardPricebookId();
        
        //Create your product
        Product2 prod = new Product2(
            Name = 'Product X',
            ProductCode = 'Pro-X',
            isActive = true
        );
        insert prod;
        
        //Create your pricebook entry
        PricebookEntry pbEntry = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbEntry;
        
        
        
        for (integer num=0;num<lstOfOpp.size();num++){
            if (num==0){
                OpportunityLineItem oppLineItem = new OpportunityLineItem(OpportunityId = lstOfOpp[num].id,
                                                                          Quantity = 1,
                                                                          PricebookEntryId = pbEntry.Id,
                                                                          TotalPrice = pbEntry.UnitPrice,
                                                                          Product_Familly__c = 'Atlassian Data Center',
                                                                          License_Start_date__c = system.today(),
                                                                          License_end_date__c = system.today().addDays(90),
                                                                          SEN__c = 'Serial Number',
                                                                          Atlassian_License_Type__c = 'New',
                                                                          Multi_or_single_invoice__c='',
                                                                          Discount__c=0.1);
                lstOfOppLineItem.add(oppLineItem); 
            } else if (num==1){
                OpportunityLineItem oppLineItem = new OpportunityLineItem(OpportunityId = lstOfOpp[num].id,
                                                                          Quantity = 1,
                                                                          PricebookEntryId = pbEntry.Id,
                                                                          TotalPrice = pbEntry.UnitPrice,
                                                                          Product_Familly__c = 'Atlassian - Services',
                                                                          License_Start_date__c = system.today(),
                                                                          License_end_date__c = system.today().addDays(90),
                                                                          SEN__c = 'Serial Number',
                                                                          Atlassian_License_Type__c = 'New Renewal');
                lstOfOppLineItem.add(oppLineItem);
            }else if(num==2){
                OpportunityLineItem oppLineItem = new OpportunityLineItem(OpportunityId = lstOfOpp[num].id,
                                                                          Quantity = 1,
                                                                          PricebookEntryId = pbEntry.Id,
                                                                          SEN__c = 'Serial Number',
                                                                          TotalPrice = pbEntry.UnitPrice);
                lstOfOppLineItem.add(oppLineItem);
                
                OpportunityLineItem oppLineItem1 = new OpportunityLineItem(OpportunityId = lstOfOpp[num].id,
                                                                           Quantity = 1,
                                                                           PricebookEntryId = pbEntry.Id,
                                                                           SEN__c = 'Serial Number',
                                                                           TotalPrice = pbEntry.UnitPrice);
                lstOfOppLineItem.add(oppLineItem1);
            }
        }
        
        
        return lstOfOppLineItem;
    }*/
}