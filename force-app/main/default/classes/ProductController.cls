/**
 * @description       :
 * @author            : tatu.lappetelainen@ceili.fi
 * @group             :
 * @last modified on  : 30-07-2026
 * @last modified by  : furkan.kokturk@eficode.com
 **/
public with sharing class ProductController {
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getRevenueTypePicklistValues() {
    List<Map<String, String>> picklistValues = new List<Map<String, String>>();
    try {
      Schema.SObjectType ot = Schema.getGlobalDescribe().get('Product2');
      Schema.DescribeSObjectResult dsr = ot.getDescribe();
      Schema.DescribeFieldResult dfr = dsr.fields.getMap()
        .get('Revenue_Type__c')
        .getDescribe();
      List<Schema.PicklistEntry> ple = dfr.getPicklistValues();
      for (Schema.PicklistEntry pickListVal : ple) {
        picklistValues.add(
          new Map<String, String>{
            'label' => pickListVal.getLabel(),
            'value' => pickListVal.getValue()
          }
        );
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
    return picklistValues;
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getProductFamilyPicklistValues() {
    List<Map<String, String>> picklistValues = new List<Map<String, String>>();
    try {
      Schema.SObjectType ot = Schema.getGlobalDescribe().get('Product2');
      Schema.DescribeSObjectResult dsr = ot.getDescribe();
      Schema.DescribeFieldResult dfr = dsr.fields.getMap()
        .get('Family')
        .getDescribe();
      List<Schema.PicklistEntry> ple = dfr.getPicklistValues();
      for (Schema.PicklistEntry pickListVal : ple) {
        picklistValues.add(
          new Map<String, String>{
            'label' => pickListVal.getLabel(),
            'value' => pickListVal.getValue()
          }
        );
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
    return picklistValues;
  }

  // Solution Area picklist replaces Business Area filter
  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getSolutionAreaPicklistValues() {
    List<Map<String, String>> picklistValues = new List<Map<String, String>>();
    try {
      Schema.SObjectType ot = Schema.getGlobalDescribe().get('Product2');
      Schema.DescribeSObjectResult dsr = ot.getDescribe();
      Schema.DescribeFieldResult dfr = dsr.fields.getMap()
        .get('Solution_Areas__c')
        .getDescribe();
      List<Schema.PicklistEntry> ple = dfr.getPicklistValues();
      for (Schema.PicklistEntry pickListVal : ple) {
        picklistValues.add(
          new Map<String, String>{
            'label' => pickListVal.getLabel(),
            'value' => pickListVal.getValue()
          }
        );
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
    return picklistValues;
  }
}