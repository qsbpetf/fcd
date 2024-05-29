/**
 * @description       :
 * @author            : tatu.lappetelainen@ceili.fi
 * @group             :
 * @last modified on  : 03-07-2024
 * @last modified by  : tatu.lappetelainen@ceili.fi
 **/
public with sharing class PricebookEntryController {
  public PricebookEntryController() {
  }

  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getPricebookEntries(
    ID oppId,
    Integer start,
    Integer pageSize,
    String sortBy,
    String sortDirection,
    String wildcard,
    String revenueType,
    String productFamily,
    String businessArea
  ) {
    Map<String, Object> result = new Map<String, Object>();
    try {
      if (String.isBlank(String.valueOf(oppId))) {
        throw new AuraHandledException('oppId is required');
      }
      if (String.isBlank(String.valueOf(start))) {
        throw new AuraHandledException('start is required');
      }
      if (String.isBlank(String.valueOf(pageSize))) {
        throw new AuraHandledException('pageSize is required');
      }
      if (String.isBlank(String.valueOf(sortBy))) {
        throw new AuraHandledException('sortBy is required');
      }
      if (String.isBlank(String.valueOf(sortDirection))) {
        throw new AuraHandledException('sortDirection is required');
      }

      String oppIdParam = String.escapeSingleQuotes(oppId);
      Opportunity opp = [
        SELECT Id, Pricebook2Id, CurrencyIsoCode
        FROM Opportunity
        WHERE Id = :oppIdParam
      ];
      System.debug('opp: ' + opp);

      if (opp == null) {
        throw new AuraHandledException('Opportunity not found');
      }

      String pricebookIdParam = String.escapeSingleQuotes(opp.Pricebook2Id);
      String currencyIsoCodeParam = String.escapeSingleQuotes(
        opp.CurrencyIsoCode
      );
      Integer startParam = start;
      Integer pageSizeParam = pageSize;
      String sortByParam = String.escapeSingleQuotes(sortBy);
      String sortDirectionParam = String.escapeSingleQuotes(sortDirection)
        .toUpperCase();
      String wildcardParam = String.isBlank(wildcard)
        ? ''
        : '%' + String.escapeSingleQuotes(wildcard) + '%';
      String revenueTypeParam = String.escapeSingleQuotes(revenueType);
      String productFamilyParam = String.escapeSingleQuotes(productFamily);
      String businessAreaParam = String.escapeSingleQuotes(businessArea);

      String pbesQuery = 'SELECT Id, UnitPrice, Product2.Name, Product2.Unit_of_Measure__c, Product2.Revenue_Type__c, Product2.Family, Product2.Business_Area__c FROM PricebookEntry';
      pbesQuery += createWhereClause(
        pricebookIdParam,
        currencyIsoCodeParam,
        wildcardParam,
        revenueTypeParam,
        productFamilyParam,
        businessAreaParam
      );
      pbesQuery += createOrderByClause(sortByParam, sortDirectionParam);
      pbesQuery += createLimitClause(startParam, pageSizeParam);
      System.debug('pbesQuery: ' + pbesQuery);
      List<PricebookEntry> pbes = Database.query(pbesQuery);
      System.debug('pbes: ' + pbes);

      String countQuery = 'SELECT COUNT() FROM PricebookEntry';
      countQuery += createWhereClause(
        pricebookIdParam,
        currencyIsoCodeParam,
        wildcardParam,
        revenueTypeParam,
        productFamilyParam,
        businessAreaParam
      );
      System.debug('countQuery: ' + countQuery);
      Integer count = Database.countQuery(countQuery);

      result.put('pbes', pbes);
      result.put('count', count);
    } catch (Exception e) {
      System.debug(e);
      throw new AuraHandledException(e.getMessage());
    }

    return result;
  }

  /**
   * Apex max limit is 2000
   * @param startParam
   * @param pageSizeParam
   * @return  `String`
   */
  private static String createLimitClause(
    Integer startParam,
    Integer pageSizeParam
  ) {
    String limitClause = ' LIMIT :pageSizeParam OFFSET :startParam';
    return limitClause;
  }

  /**
   * Apex not allowing to use variable binding in ORDER BY clause
   * @param sortByParam
   * @param sortDirectionParam
   * @return  `String`
   */
  private static String createOrderByClause(
    String sortByParam,
    String sortDirectionParam
  ) {
    String orderByClause =
      ' ORDER BY ' +
      sortByParam +
      ' ' +
      sortDirectionParam +
      ' NULLS LAST';
    return orderByClause;
  }

  private static String createWhereClause(
    String pricebookIdParam,
    String currencyIsoCodeParam,
    String wildcardParam,
    String revenueTypeParam,
    String productFamilyParam,
    String businessAreaParam
  ) {
    String whereClause = ' WHERE Pricebook2Id = :pricebookIdParam AND CurrencyIsoCode = :currencyIsoCodeParam AND IsActive = true AND Product2.IsActive = true';

    if (!String.isBlank(wildcardParam)) {
      whereClause += ' AND Product2.Name LIKE :wildcardParam';
    }
    if (!String.isBlank(revenueTypeParam)) {
      whereClause += ' AND Product2.Revenue_Type__c = :revenueTypeParam';
    }
    if (!String.isBlank(productFamilyParam)) {
      whereClause += ' AND Product2.Family = :productFamilyParam';
    }
    if (!String.isBlank(businessAreaParam)) {
      whereClause += ' AND Product2.Business_Area__c = :businessAreaParam';
    }

    return whereClause;
  }
}