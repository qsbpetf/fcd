/* 
* @author Constance Rouge
* @createddate 25/06/2020
*/

@IsTest
public class TestDataFactory {

    public static AutomationSettings__c getAutomationSettings(Boolean automationEnabled, Boolean validationEnabled) {
        return new AutomationSettings__c(
            SetupOwnerId               = UserInfo.getOrganizationId(),
            Automation_Enabled__c      = automationEnabled,
            Validation_Rule_Enabled__c = validationEnabled
        );
    }

    public static void setAutomation(Boolean enabled) {
        AutomationSettings__c settings = AutomationSettings__c.getOrgDefaults();
        settings.Automation_Enabled__c = enabled;
        settings.Validation_Rule_Enabled__c = enabled;
        // upsert without field works for Hierarchy Settings if Id is populated from getOrgDefaults
        // but if it's new, it will insert.
        upsert settings;
    }

    public static User createTestUser(String email) {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).right(5);
        String uniqueUsername = email.substringBefore('@') + uniqueSuffix + '@testorg.com';
        String alias = (email.substringBefore('@').left(3) + uniqueSuffix).left(8);
        User u = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LastName = 'TestUser',
            Email = email,
            Username = uniqueUsername,
            Alias = alias,
            CommunityNickname = email.substringBefore('@') + uniqueSuffix,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        return u;
    }

    public static User createTestUser(String email, String lastName, String aliasBase) {
        String uniqueSuffix = String.valueOf(System.currentTimeMillis()).right(5);
        String uniqueUsername = email.substringBefore('@') + uniqueSuffix + '@testorg.com';
        String alias = (aliasBase + uniqueSuffix).left(8);
        SObject userRecord = Schema.getGlobalDescribe().get('User').newSObject();
        userRecord.put('ProfileId', [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id);
        userRecord.put('LastName', lastName);
        userRecord.put('Email', email);
        userRecord.put('Username', uniqueUsername);
        userRecord.put('Alias', alias);
        userRecord.put('CommunityNickname', (aliasBase + uniqueSuffix).left(40));
        userRecord.put('TimeZoneSidKey', 'America/Los_Angeles');
        userRecord.put('LocaleSidKey', 'en_US');
        userRecord.put('EmailEncodingKey', 'UTF-8');
        userRecord.put('LanguageLocaleKey', 'en_US');
        return (User) userRecord;
    }

    public static Account getAccount(String billingCountry, String curr){
        Account acc = new Account(Name='Test Acc', BillingCountry=billingCountry, CurrencyIsoCode=curr);
        return acc;
    }

    public static Account getAccount(String name, Id ownerId, Date t1StartDate) {
        Account acc = new Account(Name = name, OwnerId = ownerId);
        if (t1StartDate != null) {
            acc.T1_Start_Date__c = t1StartDate;
        }
        return acc;
    }

    public static Contact getCon(Id accId){
        Contact con = new Contact(LastName = 'testCon', AccountId = accId);
        return con;
    }

    public static Opportunity getOpp(String accId, String curr){
        Opportunity opp = new Opportunity(Name='Test Opp', CloseDate = system.today().addDays(90),StageName = '10. Awaiting Initial Briefing Completion', AccountId = accId,
                                          Description = 'Test', NextStep = 'Test', LeadSource = 'Adwords', Type='Existing Customer', Special_Instructions_to_Accounts__c='Test',
                                          Delivery_Date__c = system.today().adddays(10), Atlassian_Payment_link__c='Test', Customer_PO_Number__c='Test PO Number', Atlassian_AT_Quote_ref__c='Test ref'
                                         );
        if(curr!=null) opp.CurrencyIsoCode=curr;
        return opp;
    }

    public static Opportunity getOpp(Id accId, Id ownerId, Date closeDate, String stageName, Decimal amount, String name) {
        Opportunity opp = new Opportunity(
            Name = String.isBlank(name) ? 'Test Opp' : name,
            CloseDate = closeDate,
            StageName = stageName,
            AccountId = accId,
            OwnerId = ownerId,
            Description = 'Test',
            NextStep = 'Test',
            LeadSource = 'Adwords',
            Type = 'Existing Customer',
            Special_Instructions_to_Accounts__c = 'Test',
            Delivery_Date__c = Date.newInstance(2026, 12, 15),
            Atlassian_Payment_link__c = 'Test',
            Customer_PO_Number__c = 'Test PO',
            Atlassian_AT_Quote_ref__c = 'Test ref'
        );
        if (amount != null) {
            opp.Amount = amount;
        }
        return opp;
    }

    public static Product2 getProduct(){
        Product2 prod=new Product2(Name='Test product', Family='OtherVendorProduct',
                                   Academic_Cost_price_Dollars__c=10, Academic_Cost_price_Euros__c=8, Academic_Cost_price_Pounds__c=7,
                                   Commercial_Cost_price_Dollars__c=20, Commercial_Cost_price_Euros__c=16, Commercial_Cost_price_Pounds__c=14);
        return prod;
    }

    public static PricebookEntry getPbEntry(Id PricebookId, Id ProductId, String curr){
        PricebookEntry pbEntry=new PricebookEntry(Pricebook2Id=PricebookId, Product2Id=ProductId, CurrencyIsoCode=curr, UnitPrice=1, IsActive=true);
        return pbEntry;
    }

    public static OpportunityLineItem getOppProd(Id pbEntryId, Id OppId){
        OpportunityLineItem oppProd=new OpportunityLineItem(OpportunityId=OppId, PricebookEntryId=pbEntryId, Quantity=1, UnitPrice=1, Editable_Cost_Price__c=1, Renewal__c='Renewal (CV Owned)');
        return oppProd;
    }

    public static Buying_Exchange_Rate__c getRate(){
        Buying_Exchange_Rate__c rate=new Buying_Exchange_Rate__c(Created_from_Test_Class__c=true, Start_Date__c=System.today()-1, Exchange_Rate_from_USD_to_EUR__c=0.8, Exchange_Rate_from_USD_to_GBP__c=0.7);
        return rate;
    }

    public static InvoiceGroup__c getInvoiceGroup(Id accId){
        InvoiceGroup__c invGroup=new InvoiceGroup__c(Name='Test Invoice Group',  AtlassianInvoiceGroupId__c='Test', Account__c=accId, CurrencyIsoCode='USD', Active__c=true, ShipToPartyName__c='Test', CV_Subsidiary__c='FI');
        return invGroup;
    }
}