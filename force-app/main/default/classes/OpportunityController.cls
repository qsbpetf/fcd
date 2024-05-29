/**
 * @description       :
 * @author            : tatu.lappetelainen@ceili.fi
 * @group             :
 * @last modified on  : 01-12-2024
 * @last modified by  : tatu.lappetelainen@ceili.fi
 **/
public with sharing class OpportunityController {
  public OpportunityController() {
  }

  @AuraEnabled(cacheable=true)
  public static Opportunity getOpportunity(ID opportunityId) {
    Opportunity opp = null;
    try {
      opp = [
        SELECT Id, CurrencyIsoCode
        FROM Opportunity
        WHERE Id = :opportunityId
      ];
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
    return opp;
  }
}