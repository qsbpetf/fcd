/**
 * Unit tests for PricebookEntryController used by the
 * Add Opportunity Products product search (pricebookEntrySearchForm LWC).
 */
@isTest
private class PricebookEntryControllerTest {
  /**
   * Returns the first active picklist value of Product2.Solution_Areas__c
   * so the test does not depend on hardcoded picklist configuration.
   */
  private static String getFirstSolutionAreaValue() {
    List<Schema.PicklistEntry> entries = Product2.Solution_Areas__c.getDescribe()
      .getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (entry.isActive()) {
        return entry.getValue();
      }
    }
    return null;
  }

  @isTest
  static void getPricebookEntriesByWildcardTest() {
    ID opportunityId = [SELECT Id FROM Opportunity LIMIT 1].Id;
    Map<String, Object> result = PricebookEntryController.getPricebookEntries(
      opportunityId,
      0,
      20,
      'Product2.Name',
      'ASC',
      'Product1',
      '',
      '',
      ''
    );
    List<PricebookEntry> pbes = (List<PricebookEntry>) result.get('pbes');
    System.assertEquals(
      'Test Product1',
      pbes[0].Product2.Name,
      'Search didn\'t find the correct product'
    );
  }

  @isTest
  static void getPricebookEntriesByRevenueTypeTest() {
    ID opportunityId = [SELECT Id FROM Opportunity LIMIT 1].Id;
    Map<String, Object> result = PricebookEntryController.getPricebookEntries(
      opportunityId,
      0,
      20,
      'Product2.Name',
      'ASC',
      '',
      'Licenses',
      '',
      ''
    );
    List<PricebookEntry> pbes = (List<PricebookEntry>) result.get('pbes');
    System.assertEquals(
      'Test Product2',
      pbes[0].Product2.Name,
      'Search didn\'t find the correct product'
    );
  }

  @isTest
  static void getPricebookEntriesByProductFamilyTest() {
    ID opportunityId = [SELECT Id FROM Opportunity LIMIT 1].Id;
    Map<String, Object> result = PricebookEntryController.getPricebookEntries(
      opportunityId,
      0,
      20,
      'Product2.Name',
      'ASC',
      '',
      '',
      'CON: Consulting',
      ''
    );
    List<PricebookEntry> pbes = (List<PricebookEntry>) result.get('pbes');
    System.assertEquals(
      'Test Product3',
      pbes[0].Product2.Name,
      'Search didn\'t find the correct product'
    );
  }

  @isTest
  static void getPricebookEntriesBySolutionAreaTest() {
    String solutionAreaValue = getFirstSolutionAreaValue();
    System.assertNotEquals(
      null,
      solutionAreaValue,
      'Product2.Solution_Areas__c has no active picklist values. Add at least one value before running this test.'
    );

    ID opportunityId = [SELECT Id FROM Opportunity LIMIT 1].Id;
    Map<String, Object> result = PricebookEntryController.getPricebookEntries(
      opportunityId,
      0,
      20,
      'Product2.Name',
      'ASC',
      '',
      '',
      '',
      solutionAreaValue
    );
    List<PricebookEntry> pbes = (List<PricebookEntry>) result.get('pbes');
    System.assertEquals(
      'Test Product4',
      pbes[0].Product2.Name,
      'Search didn\'t find the correct product'
    );
  }

  @testSetup
  static void makeData() {
    // create test data
    Product2 p1 = new Product2();
    p1.Name = 'Test Product1';
    p1.IsActive = true;
    p1.Unlimited_Users__c = true;
    insert p1;

    Product2 p2 = new Product2();
    p2.Name = 'Test Product2';
    p2.IsActive = true;
    p2.Revenue_Type__c = 'Licenses';
    p2.Unlimited_Users__c = true;
    insert p2;

    Product2 p3 = new Product2();
    p3.Name = 'Test Product3';
    p3.IsActive = true;
    p3.Family = 'CON: Consulting';
    p3.Unlimited_Users__c = true;
    insert p3;

    Product2 p4 = new Product2();
    p4.Name = 'Test Product4';
    p4.IsActive = true;
    p4.Solution_Areas__c = getFirstSolutionAreaValue();
    p4.Unlimited_Users__c = true;
    insert p4;

    Pricebook2 pb = new Pricebook2();
    pb.Name = 'Test Pricebook';
    pb.IsActive = true;
    insert pb;

    PricebookEntry pbe1 = new PricebookEntry();
    pbe1.Pricebook2Id = Test.getStandardPricebookId();
    pbe1.Product2Id = p1.Id;
    pbe1.UnitPrice = 100.00;
    pbe1.IsActive = true;
    insert pbe1;

    PricebookEntry pbe2 = new PricebookEntry();
    pbe2.Pricebook2Id = pb.Id;
    pbe2.Product2Id = p1.Id;
    pbe2.UnitPrice = 100.00;
    pbe2.IsActive = true;
    insert pbe2;

    PricebookEntry pbe3 = new PricebookEntry();
    pbe3.Pricebook2Id = Test.getStandardPricebookId();
    pbe3.Product2Id = p2.Id;
    pbe3.UnitPrice = 100.00;
    pbe3.IsActive = true;
    insert pbe3;

    PricebookEntry pbe4 = new PricebookEntry();
    pbe4.Pricebook2Id = pb.Id;
    pbe4.Product2Id = p2.Id;
    pbe4.UnitPrice = 100.00;
    pbe4.IsActive = true;
    insert pbe4;

    PricebookEntry pbe5 = new PricebookEntry();
    pbe5.Pricebook2Id = Test.getStandardPricebookId();
    pbe5.Product2Id = p3.Id;
    pbe5.UnitPrice = 100.00;
    pbe5.IsActive = true;
    insert pbe5;

    PricebookEntry pbe6 = new PricebookEntry();
    pbe6.Pricebook2Id = pb.Id;
    pbe6.Product2Id = p3.Id;
    pbe6.UnitPrice = 100.00;
    pbe6.IsActive = true;
    insert pbe6;

    PricebookEntry pbe7 = new PricebookEntry();
    pbe7.Pricebook2Id = Test.getStandardPricebookId();
    pbe7.Product2Id = p4.Id;
    pbe7.UnitPrice = 100.00;
    pbe7.IsActive = true;
    insert pbe7;

    PricebookEntry pbe8 = new PricebookEntry();
    pbe8.Pricebook2Id = pb.Id;
    pbe8.Product2Id = p4.Id;
    pbe8.UnitPrice = 100.00;
    pbe8.IsActive = true;
    insert pbe8;

    Opportunity oppo = new Opportunity();
    oppo.Name = 'Test Opportunity';
    oppo.StageName = 'Prospecting';
    oppo.CloseDate = Date.today();
    oppo.Pricebook2Id = pb.Id;
    insert oppo;
  }
}