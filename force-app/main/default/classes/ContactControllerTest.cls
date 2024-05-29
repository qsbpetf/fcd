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
private class ContactControllerTest {
  @isTest
  static void getContactsTestSuccess() {
    Map<String, Object> result = ContactController.getContacts(
      0,
      20,
      'Name',
      'asc',
      'Test'
    );
    List<Contact> cs = (List<Contact>) result.get('cs');
    System.assertEquals(
      'Test Contact1',
      cs[0].Name,
      'getContacts didn\'t find the correct contact'
    );
  }

  @isTest
  static void getContactTestSuccess() {
    Contact contact1 = [SELECT Id FROM Contact LIMIT 1];
    Contact contact2 = ContactController.getContact(contact1.Id);
    System.assertEquals(
      contact1.Id,
      contact2.Id,
      'getContact didn\'t return the correct contact'
    );
  }

  @testSetup
  static void makeData() {
    Contact contact = new Contact();
    contact.FirstName = 'Test';
    contact.LastName = 'Contact1';
    contact.Email = 'test.contact@test.fi';
    contact.Birthdate = Date.newInstance(1990, 1, 1);
    insert contact;
  }
}