function getNestedValue(obj, path) {
  return path.split(".").reduce((acc, part) => acc?.[part], obj);
}

export function formatOpportunityLineItems(opportunityLineItems) {
  return opportunityLineItems?.map((opportunityLineItem) => {
    const flat = { ...opportunityLineItem };
    const dotPaths = [
      "PricebookEntry.Id",
      "PricebookEntry.Product2Id",
      "PricebookEntry.Product2.Id",
      "PricebookEntry.Product2.Revenue_Type__c",
      "PricebookEntry.Product2.Name",
      "PricebookEntry.Product2.Unit_of_Measure__c",
      "SEN_Technical_Contact__r.Name"
    ];
    for (const path of dotPaths) {
      const val = getNestedValue(opportunityLineItem, path);
      if (val !== undefined) {
        flat[path] = val;
      }
    }
    flat.Url = `/${opportunityLineItem?.Id}`;
    return flat;
  });
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