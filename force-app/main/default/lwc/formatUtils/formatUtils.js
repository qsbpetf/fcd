export function formatOpportunityLineItems(opportunityLineItems) {
  return opportunityLineItems?.map((opportunityLineItem) => ({
    ...opportunityLineItem,
    "SEN_Technical_Contact__r.Name":
      opportunityLineItem?.SEN_Technical_Contact__r?.Name,
    "PricebookEntry.Id": opportunityLineItem?.PricebookEntry?.Id,
    "PricebookEntry.Product2Id":
      opportunityLineItem?.PricebookEntry?.Product2Id,
    "PricebookEntry.Product2.Id":
      opportunityLineItem?.PricebookEntry?.Product2?.Id,
    "PricebookEntry.Product2.Revenue_Type__c":
      opportunityLineItem?.PricebookEntry?.Product2?.Revenue_Type__c,
    "PricebookEntry.Product2.Name":
      opportunityLineItem?.PricebookEntry?.Product2?.Name,
    "PricebookEntry.Product2.Unit_of_Measure__c":
      opportunityLineItem?.PricebookEntry?.Product2?.Unit_of_Measure__c,
    Url: `/${opportunityLineItem?.Id}`
  }));
}

export function formatPricebookEntries(pricebookEntries) {
  return pricebookEntries?.map((pricebookEntry) => ({
    ...pricebookEntry,
    "Product2.Name": pricebookEntry?.Product2?.Name,
    "Product2.Revenue_Type__c": pricebookEntry?.Product2?.Revenue_Type__c,
    "Product2.Family": pricebookEntry?.Product2?.Family,
    "Product2.Business_Area__c": pricebookEntry?.Product2?.Business_Area__c,
    "Product2.Unit_of_Measure__c": pricebookEntry?.Product2?.Unit_of_Measure__c
  }));
}