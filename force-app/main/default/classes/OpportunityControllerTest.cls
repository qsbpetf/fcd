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
private class OpportunityControllerTest {
  @isTest
  static void getOpportunityTestSuccess() {
    Opportunity opp1 = [SELECT Id FROM Opportunity LIMIT 1];
    Opportunity opp2 = OpportunityController.getOpportunity(opp1.Id);
    System.assertEquals(
      opp1.Id,
      opp2.Id,
      'getOpportunity didn\'t return the correct opportunity'
    );
  }

  @isTest
  static void getOpportunityTestFailure() {
    try {
      Opportunity opp1 = OpportunityController.getOpportunity(null);
    } catch (Exception e) {
      System.assertEquals('Script-thrown exception', e.getMessage(), 'getOpportunity didn\'t throw an exception');
    }
  }
  
  @testSetup
  static void makeData() {
    Opportunity opp = new Opportunity();
    opp.Name = 'Test Opportunity';
    opp.StageName = 'Prospecting';
    opp.CloseDate = Date.today();
    opp.Amount = 1000;
    insert opp;
  }
}