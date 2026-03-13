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
    private static final String DEFAULT_SORT_FIELD = 'PricebookEntry.Product2.Name';
    private static final Integer MIN_FIELDS_FOR_DYNAMIC_QUERY = 5;

    private static final Map<String, List<String>> LEGACY_COLUMN_KEY_TO_FIELDS = new Map<String, List<String>>{
        'product' => new List<String>{
            'PricebookEntry.Product2.Name',
            'PricebookEntry.Product2.Id',
            'PricebookEntry.Product2.Revenue_Type__c',
            'PricebookEntry.Product2Id',
            'PricebookEntry.Id'
        },
        'unitOfMeasure' => new List<String>{ 'PricebookEntry.Product2.Unit_of_Measure__c' },
        'quantity' => new List<String>{ 'Quantity' },
        'unitPrice' => new List<String>{ 'UnitPrice' },
        'discount' => new List<String>{ 'Discount__c' },
        'totalSalesPrice' => new List<String>{ 'Total_List_Price_Incl_Discount__c' },
        'type' => new List<String>{ 'Renewal__c' },
        'startDate' => new List<String>{ 'License_Start_date__c' },
        'endDate' => new List<String>{ 'License_end_date__c' },
        'additionalInfo' => new List<String>{ 'Additional_Info__c' },
        'editableUnitListPriceUSD' => new List<String>{ 'Editable_Unit_List_Price_in_USD__c' },
        'editableCostPriceUSD' => new List<String>{ 'Editable_Cost_Price_in_Dollars__c' },
        'sen' => new List<String>{ 'SEN__c' },
        'userCount' => new List<String>{ 'User_Count__c' },
        'unusualDiscountReviewed' => new List<String>{ 'Unusual_discount_reviewed__c' },
        'lossReviewed' => new List<String>{ 'Loss_Reviewed__c' }
    };

    public OpportunityLineItemController() {
    }

    @AuraEnabled(Cacheable=true)
    public static List<Map<String, Object>> getColumnConfig() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            List<OpportunityLineItemColumnConfig__mdt> configs = [
                SELECT ColumnKey__c, FieldApiName__c, Label__c, Type__c, SortOrder__c, IsVisible__c,
                    InitialWidth__c, Sortable__c, TypeAttributesJson__c, CellAttributesJson__c,
                    CurrencyCode__c, PicklistFieldApiName__c, QueryFieldApiNames__c
                FROM OpportunityLineItemColumnConfig__mdt
                WHERE IsVisible__c = true
                ORDER BY SortOrder__c ASC NULLS LAST
            ];
            for (OpportunityLineItemColumnConfig__mdt config : configs) {
                String fieldApiName = String.isNotBlank(config.FieldApiName__c)
                    ? config.FieldApiName__c
                    : (String.isNotBlank(config.ColumnKey__c) && LEGACY_COLUMN_KEY_TO_FIELDS.containsKey(config.ColumnKey__c)
                        ? getLegacyFieldApiName(config.ColumnKey__c)
                        : null);
                if (String.isBlank(fieldApiName)) {
                    continue;
                }
                result.add(new Map<String, Object>{
                    'columnKey' => config.ColumnKey__c,
                    'fieldApiName' => fieldApiName,
                    'label' => config.Label__c,
                    'type' => config.Type__c,
                    'sortOrder' => config.SortOrder__c != null ? config.SortOrder__c : 999,
                    'isVisible' => config.IsVisible__c,
                    'initialWidth' => config.InitialWidth__c,
                    'sortable' => config.Sortable__c != null ? config.Sortable__c : true,
                    'typeAttributesJson' => config.TypeAttributesJson__c,
                    'cellAttributesJson' => config.CellAttributesJson__c,
                    'currencyCode' => config.CurrencyCode__c,
                    'picklistFieldApiName' => config.PicklistFieldApiName__c,
                    'queryFieldApiNames' => config.QueryFieldApiNames__c
                });
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    private static String getLegacyFieldApiName(String columnKey) {
        Map<String, String> keyToField = new Map<String, String>{
            'product' => 'Url',
            'unitOfMeasure' => 'PricebookEntry.Product2.Unit_of_Measure__c',
            'quantity' => 'Quantity',
            'unitPrice' => 'UnitPrice',
            'discount' => 'Discount__c',
            'totalSalesPrice' => 'Total_List_Price_Incl_Discount__c',
            'type' => 'Renewal__c',
            'startDate' => 'License_Start_date__c',
            'endDate' => 'License_end_date__c',
            'additionalInfo' => 'Additional_Info__c',
            'editableUnitListPriceUSD' => 'Editable_Unit_List_Price_in_USD__c',
            'editableCostPriceUSD' => 'Editable_Cost_Price_in_Dollars__c',
            'sen' => 'SEN__c',
            'userCount' => 'User_Count__c',
            'unusualDiscountReviewed' => 'Unusual_discount_reviewed__c',
            'lossReviewed' => 'Loss_Reviewed__c'
        };
        return keyToField.get(columnKey);
    }

    @AuraEnabled(Cacheable=true)
    public static List<Map<String, String>> getPicklistValues(String fieldApiName) {
        List<Map<String, String>> picklistValues = new List<Map<String, String>>();
        try {
            if (String.isBlank(fieldApiName)) {
                return picklistValues;
            }
            Schema.SObjectType ot = Schema.getGlobalDescribe().get('OpportunityLineItem');
            Schema.DescribeSObjectResult dsr = ot.getDescribe();
            Schema.DescribeFieldResult dfr = dsr.fields.getMap().get(fieldApiName)?.getDescribe();
            if (dfr == null) {
                return picklistValues;
            }
            for (Schema.PicklistEntry ple : dfr.getPicklistValues()) {
                picklistValues.add(new Map<String, String>{
                    'label' => ple.getLabel(),
                    'value' => ple.getValue()
                });
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return picklistValues;
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValuesForFields(List<String> fieldApiNames) {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        try {
            if (fieldApiNames == null || fieldApiNames.isEmpty()) {
                return result;
            }
            Set<String> uniqueFields = new Set<String>(fieldApiNames);
            for (String fieldApiName : uniqueFields) {
                if (String.isNotBlank(fieldApiName)) {
                    result.put(fieldApiName, getPicklistValues(fieldApiName));
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return result;
    }

    @AuraEnabled(Cacheable=false)
    public static Map<String, Object> getOpportunityLineItems(
        Id oppId,
        Integer start,
        Integer pageSize,
        String sortBy,
        String sortDirection,
        List<Object> columnConfigs
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

            String olisQuery;
            try {
                if (columnConfigs != null && !columnConfigs.isEmpty()) {
                    Set<String> fieldsToQuery = collectFieldsFromConfigs(columnConfigs);
                    fieldsToQuery.add('Id');
                    fieldsToQuery.add('OpportunityId');
                    fieldsToQuery.add('Name');
                    if (!fieldsToQuery.contains(sortByParam) || !isValidFieldPath(sortByParam)) {
                        sortByParam = DEFAULT_SORT_FIELD;
                    }
                    fieldsToQuery.add(sortByParam);
                    if (fieldsToQuery.size() < MIN_FIELDS_FOR_DYNAMIC_QUERY) {
                        System.debug(LoggingLevel.WARN, 'Dynamic query had too few fields (' + fieldsToQuery.size() + '), using fallback from column config');
                        olisQuery = buildFallbackQuery(sortByParam);
                    } else {
                        List<String> sortedFields = new List<String>(fieldsToQuery);
                        sortedFields.sort();
                        String selectClause = 'SELECT ' + String.join(sortedFields, ', ');
                        olisQuery = selectClause + ' FROM OpportunityLineItem';
                    }
                } else {
                    if (!isValidFieldPath(sortByParam)) {
                        sortByParam = DEFAULT_SORT_FIELD;
                    }
                    olisQuery = buildFallbackQuery(sortByParam);
                }
            } catch (Exception configEx) {
                System.debug(LoggingLevel.ERROR, 'Column config parsing failed, using fallback: ' + configEx.getMessage());
                if (!isValidFieldPath(sortByParam)) {
                    sortByParam = DEFAULT_SORT_FIELD;
                }
                olisQuery = buildFallbackQuery(sortByParam);
            }

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

    /**
     * Returns getColumnConfig() as List<Object> for collectFieldsFromConfigs.
     */
    private static List<Object> getColumnConfigAsObjectList() {
        List<Object> result = new List<Object>();
        for (Map<String, Object> m : getColumnConfig()) {
            result.add(m);
        }
        return result;
    }

    /**
     * Builds SOQL from Custom Metadata column config. Used when columnConfigs from LWC
     * is null/empty, or when dynamic query fails. Ensures admins can add columns via
     * Custom Metadata without Apex changes.
     * @param sortByField Field for ORDER BY; must be in SELECT. Validated and added if missing.
     */
    private static String buildFallbackQuery(String sortByField) {
        Set<String> fieldsToQuery = collectFieldsFromConfigs(getColumnConfigAsObjectList());
        fieldsToQuery.add('Id');
        fieldsToQuery.add('OpportunityId');
        fieldsToQuery.add('Name');
        String sortField = (String.isNotBlank(sortByField) && isValidFieldPath(sortByField))
            ? sortByField
            : DEFAULT_SORT_FIELD;
        fieldsToQuery.add(sortField);
        List<String> sortedFields = new List<String>(fieldsToQuery);
        sortedFields.sort();
        return 'SELECT ' + String.join(sortedFields, ', ') + ' FROM OpportunityLineItem';
    }

    /**
     * Collects SOQL field names from column config objects (from getColumnConfig or LWC).
     */
    private static Set<String> collectFieldsFromConfigs(List<Object> configs) {
        Set<String> fields = new Set<String>();
        if (configs == null || configs.isEmpty()) {
            return fields;
        }
        for (Object configObj : configs) {
            Map<String, Object> config;
            try {
                config = (Map<String, Object>) configObj;
            } catch (Exception e) {
                continue;
            }
            if (config == null) {
                continue;
            }
            String queryFields = (String) getConfigValue(config, 'queryFieldApiNames');
            String fieldApiName = (String) getConfigValue(config, 'fieldApiName');
            if (String.isNotBlank(queryFields)) {
                for (String f : queryFields.split(',')) {
                    String trimmed = f.trim();
                    if (String.isNotBlank(trimmed) && isValidFieldPath(trimmed)) {
                        fields.add(trimmed);
                    }
                }
            } else if (String.isNotBlank(fieldApiName) && !'Url'.equals(fieldApiName)) {
                if (isValidFieldPath(fieldApiName)) {
                    fields.add(fieldApiName);
                }
            } else if ('Url'.equals(fieldApiName)) {
                fields.add('PricebookEntry.Product2.Name');
                fields.add('PricebookEntry.Product2.Id');
                fields.add('PricebookEntry.Product2.Revenue_Type__c');
                fields.add('PricebookEntry.Product2Id');
                fields.add('PricebookEntry.Id');
            }
        }
        return fields;
    }

    private static Boolean isValidFieldPath(String path) {
        if (String.isBlank(path)) {
            return false;
        }
        return Pattern.matches('^[a-zA-Z0-9_.]+$', path);
    }

    private static Object getConfigValue(Map<String, Object> config, String key) {
        if (config.containsKey(key)) {
            return config.get(key);
        }
        for (String k : config.keySet()) {
            if (key.equalsIgnoreCase(k)) {
                return config.get(k);
            }
        }
        return null;
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
                    Solution_Areas_Formula__c,
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
        System.debug('SAVE POINT CREATED!');
        try {
            Database.SaveResult[] srs = Database.insert(olis.values(), false);
            result = formatSaveResults(srs, olis);
            Map<String, Object> errors = (Map<String, Object>) result.get('errors');
            if (errors.keySet().size() > 0) {
                System.debug('ERROR: ROLLING BACK SAVEPOINT!');
                Database.rollback(sp);
            }
        }
        catch (Exception e) {
            System.debug('EXCEPTION: ROLLING BACK SAVEPOINT!');
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
        System.debug('RESULT=' + result);
        System.debug('\n' + JSON.serializePretty(result));
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
            System.debug('CHECKING SAVE RESULT: ' + sr);
            if (!sr.isSuccess()) {
                System.debug('  Save result Failed');
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
                System.debug('  Save result successful');
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