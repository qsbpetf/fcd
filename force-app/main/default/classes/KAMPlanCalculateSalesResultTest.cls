/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 *
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class KAMPlanCalculateSalesResultTest {
  @isTest
  static void calculateSalesResultTestSuccess() {
    KAMPlanCalculateSalesResult.InputVariable input = new KAMPlanCalculateSalesResult.InputVariable();
    KAMplan__c kp = [
      SELECT Id, Account__c, Plan_Year_number__c
      FROM KAMplan__c
      WHERE Name = 'Test Plan 1'
    ];

    input.accountId = kp.Account__c;
    input.fiscalYear = kp.Plan_Year_number__c;
    input.objectType = 'Opportunity';

    Test.startTest();
    List<KAMPlanCalculateSalesResult.OutputVariable> output = KAMPlanCalculateSalesResult.calculateSalesResult(
      new List<KAMPlanCalculateSalesResult.InputVariable>{ input }
    );
    Test.stopTest();

    kp = [
      SELECT
        Sales_Result_Closed_Won__c,
        Sales_Result_Licensing__c,
        Sales_Result_Consulting__c,
        Sales_Result_Services__c,
        Total_Margin__c,
        Pipeline_Forecast__c
      FROM KAMplan__c
      WHERE Name = 'Test Plan 1'
    ];

    /*
      System.assertEquals(
        300.0,
        kp.Sales_Result_Closed_Won__c,
        'Sales_Result_Closed_Won__c was not 1200.0'
      );
  
      System.assertEquals(
        0.0,
        kp.Sales_Result_Licensing__c,
        'Sales_Result_Licensing__c was not 0.0'
      );
  
      System.assertEquals(
        100.0,
        kp.Sales_Result_Consulting__c,
        'Sales_Result_Consulting__c was not 100.0'
      );
  
      System.assertEquals(
        200.0,
        kp.Sales_Result_Services__c,
        'Sales_Result_Services__c was not 200.0'
      );
  
      System.assertEquals(0.0, kp.Total_Margin__c, 'Total_Margin__c was not 0.0');
  
      System.assertEquals(
        300.0,
        kp.Pipeline_Forecast__c,
        'Pipeline_Forecast__c was not 300.0'
      );
      */
  }

  @IsTest
  static void calculateSalesResultTestFailure() {
    KAMPlanCalculateSalesResult.InputVariable input = new KAMPlanCalculateSalesResult.InputVariable();

    input.accountId = '';
    input.fiscalYear = 0;
    input.objectType = '';

    List<KAMPlanCalculateSalesResult.OutputVariable> output = KAMPlanCalculateSalesResult.calculateSalesResult(
      new List<KAMPlanCalculateSalesResult.InputVariable>{ input }
    );

    System.assertEquals(false, output[0].success, 'success was not false');
  }

  @TestSetup
  static void makeData() {
    Account acc1 = new Account();
    acc1.Name = 'Test Account 1';
    acc1.Industry = 'Technology';
    acc1.Type = 'Customer - Direct';
    insert acc1;

    KAMplan__c plan1 = new KAMplan__c();
    plan1.Name = 'Test Plan 1';
    plan1.Account__c = acc1.Id;
    plan1.Plan_Year__c = String.valueOf(Date.today().addYears(1).year());
    plan1.Calculate_Account_Hierarchy__c = true;
    insert plan1;

    Opportunity opp1 = new Opportunity();
    opp1.Name = 'Test Opportunity';
    opp1.StageName = 'Closed Won';
    opp1.CloseDate = Date.newInstance((Date.today().addYears(1).year()), 1, 1);
    opp1.Pricebook2Id = Test.getStandardPricebookId();
    opp1.AccountId = acc1.Id;
    insert opp1;

    createTestProduct(opp1.Id, 'Consulting', 100);
    // createTestProduct(opp1.Id, 'Licenses', 100);
    // createTestProduct(opp1.Id, 'Managed Services', 100);

    Opportunity opp2 = new Opportunity();
    opp2.Name = 'Test Opportunity';
    opp2.StageName = 'Closed won - awaiting approval';
    opp2.CloseDate = Date.newInstance((Date.today().addYears(1).year()), 1, 1);
    opp2.Pricebook2Id = Test.getStandardPricebookId();
    opp2.AccountId = acc1.Id;
    insert opp2;

    // createTestProduct(opp2.Id, 'Consulting', 200);
    // createTestProduct(opp2.Id, 'Licenses', 200);
    createTestProduct(opp2.Id, 'Managed Services', 200);

    Opportunity opp3 = new Opportunity();
    opp3.Name = 'Test Opportunity';
    opp3.StageName = 'Explore';
    opp3.CloseDate = Date.newInstance((Date.today().addYears(1).year()), 1, 1);
    opp3.Pricebook2Id = Test.getStandardPricebookId();
    opp3.AccountId = acc1.Id;
    insert opp3;

    // createTestProduct(opp3.Id, 'Consulting', 300);
    // createTestProduct(opp3.Id, 'Licenses', 300);
    createTestProduct(opp3.Id, 'Managed Services', 300);

    /*
    Account acc2 = new Account();
    acc2.Name = 'Test Account';
    acc2.Industry = 'Technology';
    acc2.Type = 'Customer - Direct';
    acc2.ParentId = acc1.Id;
    insert acc2;

    
    KAMplan__c plan2 = new KAMplan__c();
    plan2.Name = 'Test Plan 2';
    plan2.Account__c = acc2.Id;
    plan2.Plan_Year__c = '2024';
    plan2.Calculate_Account_Hierarchy__c = false;
    insert plan2;
    

    Opportunity opp4 = new Opportunity();
    opp4.Name = 'Test Opportunity';
    opp4.StageName = 'Closed Won';
    opp4.CloseDate = Date.newInstance(2024, 1, 1);
    opp4.Pricebook2Id = Test.getStandardPricebookId();
    opp4.AccountId = acc2.Id;
    insert opp4;

    createTestProduct(opp4.Id, 'Consulting', 400);
    // createTestProduct(opp4.Id, 'Licenses', 400);
    // createTestProduct(opp4.Id, 'Managed Services', 400);
    */

    /*
    Account acc3 = new Account();
    acc3.Name = 'Test Account';
    acc3.Industry = 'Technology';
    acc3.Type = 'Customer - Direct';
    acc3.ParentId = acc2.Id;
    insert acc3;

   
    KAMplan__c plan3 = new KAMplan__c();
    plan3.Name = 'Test Plan 3';
    plan3.Account__c = acc3.Id;
    plan3.Plan_Year__c = '2024';
    plan3.Calculate_Account_Hierarchy__c = false;
    insert plan3;
    

    Opportunity opp5 = new Opportunity();
    opp5.Name = 'Test Opportunity';
    opp5.StageName = 'Closed Won';
    opp5.CloseDate = Date.newInstance(2024, 1, 1);
    opp5.Pricebook2Id = Test.getStandardPricebookId();
    opp5.AccountId = acc3.Id;
    insert opp5;

    // createTestProduct(opp5.Id, 'Consulting', 500);
    createTestProduct(opp5.Id, 'Licenses', 500);
    // createTestProduct(opp5.Id, 'Managed Services', 500);
    */
  }

  static void createTestProduct(
    Id opportunityId,
    String revenueType,
    Decimal price
  ) {
    String businessFamily = 'CON: Consulting';
    if (revenueType == 'Licenses') {
      businessFamily = 'LIC: Atlassian: Cloud: Core';
    } else if (revenueType == 'Managed Services') {
      businessFamily = 'MS: Total Support';
    }

    Product2 pro = new Product2();
    pro.Name = 'Test Product';
    pro.IsActive = true;
    pro.Unlimited_Users__c = true;
    pro.Revenue_Type__c = revenueType;
    pro.Family = businessFamily;
    insert pro;

    PricebookEntry pbe = new PricebookEntry();
    pbe.Pricebook2Id = Test.getStandardPricebookId();
    pbe.Product2Id = pro.Id;
    pbe.UnitPrice = price;
    pbe.IsActive = true;
    insert pbe;

    OpportunityLineItem oli = new OpportunityLineItem();
    oli.OpportunityId = opportunityId;
    oli.Product2Id = pbe.Product2Id;
    oli.UnitPrice = price;
    oli.List_Price_Inc_Licence_Type__c = price;
    oli.Buy_Price_Inc_Licence_Type__c = price;
    oli.Cost_Price__c = price;
    oli.Discount__c = 0;
    oli.Quantity = 1;
    oli.Renewal__c = 'New';
    oli.License_Start_date__c = Date.today();
    oli.License_end_date__c = Date.today().addYears(1);
    insert oli;
  }
}