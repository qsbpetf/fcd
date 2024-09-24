/* 
* @author Constance Rouge
* @createddate 25/06/2020
*/

@IsTest
public class TestDataFactory {

    public static Account getAccount(String billingCountry, String curr){
        Account acc = new Account(Name='Test Acc', BillingCountry=billingCountry, CurrencyIsoCode=curr);
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

    public static Product2 getProduct(){
        Product2 prod=new Product2(Name='Test product', Family='OtherVendorProduct',
                                   Academic_Cost_price_Dollars__c=10, Academic_Cost_price_Euros__c=8, Academic_Cost_price_Pounds__c=7,
                                   Commercial_Cost_price_Dollars__c=20, Commercial_Cost_price_Euros__c=16, Commercial_Cost_price_Pounds__c=14);
        return prod;
    }

    public static PricebookEntry getPbEntry(Id PricebookId, Id ProductId, String curr){
        PricebookEntry pbEntry=new PricebookEntry(Pricebook2Id=PricebookId, Product2Id=ProductId, CurrencyIsoCode=curr, UnitPrice=1, isActive=true);
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