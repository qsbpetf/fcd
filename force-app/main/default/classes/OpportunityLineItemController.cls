/**
 * :
 *
 * @author : tatu.lappetelainen@ceili.fi
 *
 * @group :
 * @last modified on  : 03-08-2024
 * @last modified by  : tatu.lappetelainen@ceili.fi
 **/
public with sharing class OpportunityLineItemController {
    public OpportunityLineItemController() {
    }

    @AuraEnabled(Cacheable=false)
    public static Map<String, Object> getOpportunityLineItems(
        Id oppId,
        Integer start,
        Integer pageSize,
        String sortBy,
        String sortDirection
    ) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            if (oppId == null || String.isBlank(String.valueOf(oppId))) {
                throw new AuraHandledException('oppId is required');
            }
            if (start == null || String.isBlank(String.valueOf(start))) {
                throw new AuraHandledException('start is required');
            }
            if (pageSize == null || String.isBlank(String.valueOf(pageSize))) {
                throw new AuraHandledException('pageSize is required');
            }
            if (sortBy == null || String.isBlank(String.valueOf(sortBy))) {
                throw new AuraHandledException('sortBy is required');
            }
            if (
                sortDirection == null || String.isBlank(String.valueOf(sortDirection))
            ) {
                throw new AuraHandledException('sortDirection is required');
            }

            String oppIdParam = String.escapeSingleQuotes(oppId);
            Integer startParam = start;
            Integer pageSizeParam = pageSize;
            String sortByParam = String.escapeSingleQuotes(sortBy);
            String sortDirectionParam = String.escapeSingleQuotes(sortDirection)
                .toUpperCase();

            String olisQuery = 'SELECT Id, OpportunityId, Name, Renewal__c, UnitPrice, Quantity, Discount__c, Total_List_Price_Incl_Discount__c, License_Start_date__c, License_end_date__c, Additional_Info__c, Loss_Reviewed__c, SEN__c, User_Count__c, Unusual_discount_reviewed__c, Editable_Cost_Price_in_Dollars__c, Editable_Unit_List_Price_in_USD__c, PricebookEntry.Product2.Revenue_Type__c, PricebookEntry.Product2.Name, PricebookEntry.Product2.Unit_of_Measure__c FROM OpportunityLineItem';

            olisQuery += createWhereClause(oppIdParam);
            olisQuery += createOrderByClause(sortByParam, sortDirectionParam);
            olisQuery += createLimitClause(startParam, pageSizeParam);

            List<OpportunityLineItem> olis = Database.query(olisQuery);
            System.debug('olis: ' + olis);

            String countQuery = 'SELECT COUNT() FROM OpportunityLineItem';
            countQuery += createWhereClause(oppIdParam);
            System.debug('countQuery: ' + countQuery);

            Integer count = Database.countQuery(countQuery);

            result.put('olis', olis);
            result.put('count', count);
        }
        catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }

        return result;
    }

    /**
     * Apex max limit is 2000
     *
     * @param startParam
     * @param pageSizeParam
     *
     * @return `String`
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
     *
     * @param sortByParam
     * @param sortDirectionParam
     *
     * @return `String`
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

    private static String createWhereClause(String oppIdParam) {
        String whereClause = ' WHERE OpportunityId = :oppIdParam';
        return whereClause;
    }

    @AuraEnabled(Cacheable=false)
    public static List<OpportunityLineItem> getOpportunityLineItemsByIds(
        List<Id> oliIds
    ) {
        try {
            return [
                SELECT
                    Id,
                    OpportunityId,
                    Name,
                    Renewal__c,
                    Total_List_Price_Incl_Discount__c,
                    UnitPrice,
                    Quantity,
                    Discount__c,
                    License_Start_date__c,
                    License_end_date__c,
                    Additional_Info__c,
                    Editable_Cost_Price_in_Dollars__c,
                    Editable_Unit_List_Price_in_USD__c,
                    SEN__c,
                    User_Count__c,
                    Loss_Reviewed__c,
                    Unusual_discount_reviewed__c,
                    PricebookEntry.Product2.Revenue_Type__c,
                    PricebookEntry.Product2.Name,
                    PricebookEntry.Product2.Unit_of_Measure__c
                FROM OpportunityLineItem
                WHERE Id IN :oliIds
            ];
        }
        catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(Cacheable=true)
    public static List<Map<String, String>> getTypePicklistValues() {
        List<Map<String, String>> picklistValues = new List<Map<String, String>>();
        try {
            Schema.SObjectType ot = Schema.getGlobalDescribe()
                .get('OpportunityLineItem');
            Schema.DescribeSObjectResult dsr = ot.getDescribe();
            Schema.DescribeFieldResult dfr = dsr.fields.getMap()
                .get('Renewal__c')
                .getDescribe();
            List<Schema.PicklistEntry> ples = dfr.getPicklistValues();
            for (Schema.PicklistEntry ple : ples) {
                picklistValues.add(
                    new Map<String, String> {
                        'label' => ple.getLabel(),
                        'value' => ple.getValue()
                    }
                );
            }
        }
        catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return picklistValues;
    }

    @AuraEnabled(Cacheable=false)
    public static Map<String, Object> insertOpportunityLineItems(
        Map<String, OpportunityLineItem> olis
    ) {
        Map<String, Object> result = new Map<String, Object>();
        Savepoint sp = Database.setSavepoint();
        try {
            Database.SaveResult[] srs = Database.insert(olis.values(), false);
            result = formatSaveResults(srs, olis);
            Map<String, Object> errors = (Map<String, Object>) result.get('errors');
            if (errors.keySet().size() > 0) {
                Database.rollback(sp);
            }
        }
        catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    @AuraEnabled(Cacheable=false)
    public static Map<String, Object> updateOpportunityLineItems(
        Map<String, OpportunityLineItem> olis
    ) {
        Map<String, Object> result = new Map<String, Object>();
        Savepoint sp = Database.setSavepoint();
        try {
            Database.SaveResult[] srs = Database.update(olis.values(), false);
            result = formatSaveResults(srs, olis);
            Map<String, Object> errors = (Map<String, Object>) result.get('errors');
            if (errors.keySet().size() > 0) {
                Database.rollback(sp);
            }
        }
        catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    @AuraEnabled(Cacheable=false)
    public static Map<String, Object> deleteOpportunityLineItems(
        List<Id> oliIds
    ) {
        Map<String, Object> result = new Map<String, Object>();
        Savepoint sp = Database.setSavepoint();
        try {
            Database.DeleteResult[] drs = Database.delete(oliIds, false);
            result = formatDeleteResults(drs);
            Map<String, String> errors = (Map<String, String>) result.get('errors');
            if (errors.keySet().size() > 0) {
                Database.rollback(sp);
            }
        }
        catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    private static Map<String, Object> formatDeleteResults(
        Database.DeleteResult[] drs
    ) {
        Map<String, Object> result = new Map<String, Object>();
        Map<String, String> des = new Map<String, String>();
        List<Id> ids = new List<Id>();

        for (Database.DeleteResult dr : drs) {
            if (!dr.isSuccess()) {
                String id = String.valueOf(dr.getId());
                for (Database.Error e : dr.getErrors()) {
                    String message = e.getMessage();
                    des.put(id, message);
                }
            } else {
                ids.add(dr.getId());
            }
        }

        result.put('errors', des);
        result.put('ids', ids);

        return result;
    }

    private static Map<String, Object> formatSaveResults(
        Database.SaveResult[] srs,
        Map<String, OpportunityLineItem> olis
    ) {
        Map<String, Object> result = new Map<String, Object>();
        Map<String, Object> des = new Map<String, Object>();
        Map<String, Object> res = new Map<String, Object>();
        List<String> tes = new List<String>();
        List<Id> ids = new List<Id>();
        List<String> keys = new List<String>(olis.keySet());
        Integer index = 0;

        for (Database.SaveResult sr : srs) {
            if (!sr.isSuccess()) {
                String kid = keys[index];
                List<String> msgs = new List<String>();
                List<String> fns = new List<String>();

                for (Database.Error e : sr.getErrors()) {
                    String msg = e.getMessage();
                    String[] fs = e.getFields();
                    Integer rn = index + 1;

                    msgs.add(msg);
                    for (String f : fs) {
                        fns.add(f);
                    }
                    tes.add('Row ' + rn + ' ' + msg);
                }

                String title = 'We found ' + msgs.size() + ' error(s) on this row';

                Map<String, Object> re = new Map<String, Object> {
                    'fieldNames' => fns,
                    'messages' => msgs,
                    'title' => title
                };

                res.put(kid, re);
            } else {
                ids.add(sr.getId());
            }
            index++;
        }

        if (tes.size() > 0) {
            Map<String, Object> te = new Map<String, Object> {
                'title' => 'Your entry cannot be saved. Fix the errors and try again.',
                'messages' => tes
            };

            des.put('rows', res);
            des.put('table', te);
        }

        result.put('errors', des);
        result.put('ids', ids);

        return result;
    }
}