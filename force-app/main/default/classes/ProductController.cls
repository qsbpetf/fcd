/**
 * @description       :
 * @author            : tatu.lappetelainen@ceili.fi
 * @group             :
 * @last modified on  : 01-08-2024
 * @last modified by  : tatu.lappetelainen@ceili.fi
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

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getBusinessAreaPicklistValues() {
    List<Map<String, String>> picklistValues = new List<Map<String, String>>();
    try {
      Schema.SObjectType ot = Schema.getGlobalDescribe().get('Product2');
      Schema.DescribeSObjectResult dsr = ot.getDescribe();
      Schema.DescribeFieldResult dfr = dsr.fields.getMap()
        .get('Business_Area__c')
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