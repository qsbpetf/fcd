/**
 * @description       :
 * @author            : tatu.lappetelainen@ceili.fi
 * @group             :
 * @last modified on  : 01-11-2024
 * @last modified by  : tatu.lappetelainen@ceili.fi
 **/
public with sharing class ContactController {
  public ContactController() {
  }

  @AuraEnabled(cacheable=false)
  public static Map<String, Object> getContacts(
    Integer start,
    Integer pageSize,
    String sortBy,
    String sortDirection,
    String wildcard
  ) {
    Map<String, Object> result = new Map<String, Object>();
    try {
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

      Integer startParam = start;
      Integer pageSizeParam = pageSize;
      String sortByParam = String.escapeSingleQuotes(sortBy);
      String sortDirectionParam = String.escapeSingleQuotes(sortDirection)
        .toUpperCase();
      String wildcardParam = String.isBlank(wildcard)
        ? ''
        : '%' + String.escapeSingleQuotes(wildcard) + '%';

      String csQuery = 'SELECT Id, Name FROM Contact';
      csQuery += createWhereClause(wildcardParam);
      csQuery += createOrderByClause(sortByParam, sortDirectionParam);
      csQuery += createLimitClause(startParam, pageSizeParam);
      System.debug('csQuery: ' + csQuery);
      List<Contact> cs = Database.query(csQuery);
      System.debug('cs: ' + cs);

      String countQuery = 'SELECT COUNT() FROM Contact';
      countQuery += createWhereClause(wildcardParam);
      System.debug('countQuery: ' + countQuery);
      Integer count = Database.countQuery(countQuery);

      result.put('cs', cs);
      result.put('count', count);
    } catch (Exception e) {
      System.debug(e);
      throw new AuraHandledException(e.getMessage());
    }

    return result;
  }

  @AuraEnabled(cacheable=true)
  public static Contact getContact(ID contactId) {
    Contact contact = null;
    try {
      contact = [SELECT Id, Name FROM Contact WHERE Id = :contactId];
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
    return contact;
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

  private static String createWhereClause(String wildcardParam) {
    String whereClause = '';
    if (!String.isBlank(wildcardParam)) {
      whereClause += ' WHERE Name LIKE :wildcardParam';
    }
    return whereClause;
  }
}