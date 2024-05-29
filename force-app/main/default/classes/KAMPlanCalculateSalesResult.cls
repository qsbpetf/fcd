/**
 * @description       :
 * @author            : tatu.lappetelainen@ceili.fi
 * @group             :
 * @last modified on  : 04-11-2024
 * @last modified by  : tatu.lappetelainen@ceili.fi
 **/
public with sharing class KAMPlanCalculateSalesResult {
  public class InputVariable {
    public InputVariable() {
      accountId = null;
      fiscalYear = null;
      objectType = null;
    }

    @InvocableVariable(
      label='Account ID'
      description='ID of account that needs to be calculated.'
    )
    public String accountId;

    @InvocableVariable(
      label='Fiscal Year'
      description='Fiscal year for the calculation. e.g. 2024.'
    )
    public Decimal fiscalYear;

    @InvocableVariable(
      label='Object Type'
      description='Object type of record that is triggering calculation. e.g. Opportunity or KAMPlan.'
    )
    public String objectType;
  }

  public class OutputVariable {
    public OutputVariable() {
      success = true;
    }

    @InvocableVariable(
      label='Succss'
      description='True if calculation was successful. False if not.'
    )
    public Boolean success;
  }

  public class SalesResult {
    public SalesResult() {
      salesResultClosedWon = 0.0;
      salesResultLicensing = 0.0;
      salesResultConsulting = 0.0;
      salesResultServices = 0.0;
      totalMargin = 0.0;
      pipelineForecast = 0.0;
    }

    public Double salesResultClosedWon;
    public Double salesResultConsulting;
    public Double salesResultLicensing;
    public Double salesResultServices;
    public Double totalMargin;
    public Double pipelineForecast;
  }

  @InvocableMethod(
    label='Calculate Sales Result'
    description='Calculate Sales Result'
  )
  public static List<OutputVariable> calculateSalesResult(
    List<InputVariable> inputs
  ) {
    List<OutputVariable> outputs = new List<OutputVariable>();
    for (InputVariable input : inputs) {
      OutputVariable output = new OutputVariable();
      try {
        Decimal fiscalYear = input.fiscalYear;
        String accountId = input.accountId;
        String objectType = input.objectType;
        if (fiscalYear == null) {
          throw new AuraHandledException('fiscalYear is required.');
        }
        if (accountId == null) {
          throw new AuraHandledException('accountId is required.');
        }
        if (objectType == null) {
          throw new AuraHandledException('objectType is required.');
        }
        List<ID> accountIds = new List<ID>();
        if (objectType.equalsIgnoreCase('opportunity')) {
          accountIds.addAll(getParentAccountIds(new List<ID>{ accountId }));
        }
        accountIds.add(accountId);
        List<KAMplan__c> kamPlans = [
          SELECT
            Id,
            Calculate_Account_Hierarchy__c,
            Plan_Year_number__c,
            Account__c
          FROM KAMplan__c
          WHERE Account__c IN :accountIds AND Plan_Year_number__c = :fiscalYear
        ];
        for (KAMplan__c kamPlan : kamPlans) {
          SalesResult salesResult = calculatePlanSalesResult(kamPlan);
          kamPlan.Sales_Result_Closed_Won__c = salesResult.salesResultClosedWon;
          kamPlan.Sales_Result_Licensing__c = salesResult.salesResultLicensing;
          kamPlan.Sales_Result_Consulting__c = salesResult.salesResultConsulting;
          kamPlan.Sales_Result_Services__c = salesResult.salesResultServices;
          kamPlan.Total_Margin__c = salesResult.totalMargin;
          kamPlan.Pipeline_Forecast__c = salesResult.pipelineForecast;
        }
        if (kamPlans.size() > 0) {
          update kamPlans;
        }
      } catch (Exception e) {
        System.debug(
          'Exception was thrown during execution of calculateSalesResult'
        );
        System.debug(e);
        output.success = false;
      }
      outputs.add(output);
    }
    return outputs;
  }

  private static SalesResult calculatePlanSalesResult(KAMplan__c kamPlan) {
    SalesResult salesResult = new SalesResult();
    try {
      ID accountId = kamPlan.Account__c;
      Decimal fiscalYear = kamPlan.Plan_Year_number__c;
      Boolean calculateChildAccounts = kamPlan.Calculate_Account_Hierarchy__c;
      if (fiscalYear == null) {
        throw new AuraHandledException('Fiscal year is required.');
      }
      if (accountId == null) {
        throw new AuraHandledException('Account ID is required.');
      }
      List<ID> accountIds = new List<ID>();
      if (calculateChildAccounts) {
        accountIds.addAll(getChildAccountIds(new List<ID>{ accountId }));
      }
      accountIds.add(accountId);
      if (accountIds.size() < 1) {
        throw new AuraHandledException('No accounts found.');
      }
      List<Opportunity> closedOpportunities = [
        SELECT
          Id,
          Total_Amount__c,
          Roll_Up_Services_Products__c,
          Roll_up_Licensing_products__c,
          Roll_Up_Consulting_producs__c,
          Total_Margin_Declarative__c
        FROM Opportunity
        WHERE
          AccountId IN :accountIds
          AND Close_date_FY__c = :fiscalYear
          AND (StageName = 'Closed Won'
          OR StageName = 'Closed won - awaiting approval')
      ];
      for (Opportunity opportunity : closedOpportunities) {
        salesResult.salesResultClosedWon += getOpportunityFieldValueDouble(
          opportunity,
          'Total_Amount__c'
        );
        salesResult.salesResultServices += getOpportunityFieldValueDouble(
          opportunity,
          'Roll_Up_Services_Products__c'
        );
        salesResult.salesResultLicensing += getOpportunityFieldValueDouble(
          opportunity,
          'Roll_up_Licensing_products__c'
        );
        salesResult.salesResultConsulting += getOpportunityFieldValueDouble(
          opportunity,
          'Roll_Up_Consulting_producs__c'
        );
        salesResult.totalMargin += getOpportunityFieldValueDouble(
          opportunity,
          'Total_Margin_Declarative__c'
        );
      }
      List<Opportunity> openOpportunities = [
        SELECT Id, Total_Amount__c
        FROM Opportunity
        WHERE
          AccountId IN :accountIds
          AND Close_date_FY__c = :fiscalYear
          AND (StageName = 'Explore'
          OR StageName = 'Identify Needs'
          OR StageName = 'Develop Solution'
          OR StageName = 'Evaluate'
          OR StageName = 'Justify'
          OR StageName = 'Closing')
      ];
      for (Opportunity opportunity : openOpportunities) {
        salesResult.pipelineForecast += getOpportunityFieldValueDouble(
          opportunity,
          'Total_Amount__c'
        );
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
    return salesResult;
  }

  private static Double getOpportunityFieldValueDouble(
    Opportunity opportunity,
    String fieldName
  ) {
    Double fieldValue = 0.0;
    try {
      if (opportunity != null && opportunity.get(fieldName) != null) {
        fieldValue = (Double) opportunity.get(fieldName);
      }
    } catch (Exception e) {
      System.debug(e);
    }
    return fieldValue;
  }

  private static List<ID> getChildAccountIds(List<ID> accountIds) {
    List<ID> childAccountIds = new List<ID>();
    if (accountIds.size() < 1) {
      return childAccountIds;
    }
    List<Account> childAccounts = [
      SELECT Id
      FROM Account
      WHERE ParentId IN :accountIds
    ];
    for (Account childAccount : childAccounts) {
      childAccountIds.add(childAccount.Id);
    }
    childAccountIds.addAll(getChildAccountIds(childAccountIds));
    return childAccountIds;
  }

  private static List<ID> getParentAccountIds(List<ID> accountIds) {
    List<ID> parentAccountIds = new List<ID>();
    if (accountIds.size() < 1) {
      return parentAccountIds;
    }
    List<Account> parentAccounts = [
      SELECT ParentId
      FROM Account
      WHERE Id IN :accountIds
    ];
    for (Account parentAccount : parentAccounts) {
      parentAccountIds.add(parentAccount.ParentId);
    }
    parentAccountIds.addAll(getParentAccountIds(parentAccountIds));
    return parentAccountIds;
  }
}