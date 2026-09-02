/**
 * Unit tests for ProductController picklist value methods used by the
 * Add Opportunity Products LWC filter comboboxes.
 */
@isTest
private class ProductControllerTest {
  @isTest
  static void getRevenueTypePicklistValuesTest() {
    List<Map<String, String>> revenueTypePicklistValues = ProductController.getRevenueTypePicklistValues();
    System.assertNotEquals(
      0,
      revenueTypePicklistValues.size(),
      'revenueTypePicklistValues was empty'
    );
  }

  @isTest
  static void getProductFamilyPicklistValuesTest() {
    List<Map<String, String>> productFamilyPicklistValues = ProductController.getProductFamilyPicklistValues();
    System.assertNotEquals(
      0,
      productFamilyPicklistValues.size(),
      'productFamilyPicklistValues was empty'
    );
  }

  @isTest
  static void getSolutionAreaPicklistValuesTest() {
    List<Map<String, String>> solutionAreaPicklistValues = ProductController.getSolutionAreaPicklistValues();
    System.assertNotEquals(
      0,
      solutionAreaPicklistValues.size(),
      'solutionAreaPicklistValues was empty'
    );
    // Each entry must expose label and value keys for the LWC combobox
    for (Map<String, String> entry : solutionAreaPicklistValues) {
      System.assert(
        entry.containsKey('label') && entry.containsKey('value'),
        'Picklist entry must contain label and value'
      );
    }
  }
}