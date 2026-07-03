public with sharing class TierCalcService {

    // Calculates and updates tier lines for a set of opportunities based on a specific date
    public static List<Tier__c> calculateFor(Set<Id> oppIds, Date asOfDate) {
        if (oppIds == null || oppIds.isEmpty()) return null;

        // Load all required data
        Map<Id, Opportunity> oppMap = loadOpportunities(oppIds);
        Map<Id, Account> accMap = loadAccounts(oppMap);
        Map<Id, List<OpportunityLineItem>> oliByOpp = loadOpportunityLineItems(oppIds);
        Map<Id, Map<Id, Decimal>> oppSplitsByOpp = loadOpportunitySplits(oppIds);
        Map<Id, Map<Id, Tier__c>> existingLinesByOpp = loadExistingTierLines(oppIds);

        // Compute and save tier lines
        List<Tier__c> upserted = computeTierLines(
            oppMap, accMap, oliByOpp, oppSplitsByOpp, existingLinesByOpp, asOfDate
        );

        System.debug('Tier lines calculated and saved: ' + upserted);
        return upserted;
    }

    // Loads opportunity records with all required fields for tier calculation
    // Returns: Map<Opp ID, Opportunity>
    private static Map<Id, Opportunity> loadOpportunities(Set<Id> oppIds) {
        return new Map<Id, Opportunity>([
            SELECT Id, Name, AccountId, OwnerId, CloseDate, StageName, CurrencyIsoCode,
                Payment_Terms__c, Deal_Reg_Rebate_Value_Currency__c,
                Deal_Reg_Rebate_Value__c, Exchange_Rate_from_Products__c,
                Related_Project__c, Project_Type__c, Total_Amount__c,
                T2_Override__c, T3_Override__c,
                Estimate_Consulting_Revenue__c, Estimate_Managed_Service_Revenue__c, Estimate_Licensing_GP__c,
                Total_Amount_T2__c, Total_Amount_T3__c,
                Project_Start_Date_From_Project__c, T3_From_Products__c,
                Atlassian_PVR_Rebate_Currency__c
            FROM Opportunity WHERE Id IN :oppIds
        ]);
    }

    // Loads account records related to the opportunities
    // Returns: Map<Account ID, Account>
    private static Map<Id, Account> loadAccounts(Map<Id, Opportunity> oppMap) {
        Set<Id> accIds = new Set<Id>();
        for (Opportunity o : oppMap.values()) {
            if (o.AccountId != null) accIds.add(o.AccountId);
        }

        return accIds.isEmpty() ? new Map<Id,Account>() : new Map<Id,Account>([
            SELECT Id, Name, CurrencyIsoCode
            FROM Account WHERE Id IN :accIds
        ]);
    }

    // Loads and groups opportunity line items by their parent opportunity ID
    // Returns: Map<Opportunity ID, List<Opportunity Line Item>>
    private static Map<Id, List<OpportunityLineItem>> loadOpportunityLineItems(Set<Id> oppIds) {
        Map<Id, List<OpportunityLineItem>> oliByOpp = new Map<Id, List<OpportunityLineItem>>();
        for (OpportunityLineItem oli : [
            SELECT Id, OpportunityId, TotalPrice, Quantity, UnitPrice, CurrencyIsoCode,
                Product2Id, Product2.Family, Product_Familly__c, Margin_Value__c,
                License_Start_date__c, License_end_date__c, T3_Product__c,
                User_Count__c, days__c, Revenue_Type_Formula__c, Renewal__c,
                Total_List_Price_Incl_Discount__c, T2_Attainment_Amount__c
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds
        ]) {
            if (!oliByOpp.containsKey(oli.OpportunityId)) {
                oliByOpp.put(oli.OpportunityId, new List<OpportunityLineItem>());
            }
            oliByOpp.get(oli.OpportunityId).add(oli);
        }
        return oliByOpp;
    }


    // Loads existing tier lines and organizes them by opportunity ID and user ID for comparison.
    // Returns: Map<Opportunity ID, Map<User ID, Tier Line>>
    private static Map<Id, Map<Id, Tier__c>> loadExistingTierLines(Set<Id> oppIds) {
        Map<Id, Map<Id, Tier__c>> existingLinesByOpp = new Map<Id, Map<Id, Tier__c>>();
        for (Tier__c oldLine : [
            SELECT Id, Opportunity__c, User__c, Input_Hash__c, Line_Key__c
            FROM Tier__c
            WHERE Opportunity__c IN :oppIds
        ]) {
            if (!existingLinesByOpp.containsKey(oldLine.Opportunity__c)) {
                existingLinesByOpp.put(oldLine.Opportunity__c, new Map<Id, Tier__c>());
            }
            existingLinesByOpp.get(oldLine.Opportunity__c).put(oldLine.User__c, oldLine);
        }
        return existingLinesByOpp;
    }

    // Calculates revenue percentages for each user on the specified opportunities
    // Returns: Map structure: OpportunityId => (UserId => Percentage)
    //          Example: { Opp1 => { User1 => 60.0, User2 => 40.0 }, Opp2 => { User3 => 100.0 } }
    public static Map<Id, Map<Id, Decimal>> loadOpportunitySplits(Set<Id> oppIds) {
        // Initialize nested map to store split percentages by opportunity and user
        // OpportunityId => (UserId => Percentage)
        Map<Id, Map<Id, Decimal>> byOpp = new Map<Id, Map<Id, Decimal>>();

        // Query all splits for the given opportunities
        for (OpportunitySplit s : [
            SELECT OpportunityId, SplitOwnerId, SplitPercentage, SplitType.DeveloperName
            FROM OpportunitySplit
            WHERE OpportunityId IN :oppIds
        ]) {
            if (!byOpp.containsKey(s.OpportunityId)) {
                byOpp.put(s.OpportunityId, new Map<Id, Decimal>());
            }

            // Get the map of users and their percentages for this opportunity
            Map<Id, Decimal> oppMap = byOpp.get(s.OpportunityId);

            // Get the current percentage for this user (0 if not set)
            Decimal current = oppMap.get(s.SplitOwnerId) ?? 0;

            // Get the split percentage (0 if null)
            Decimal splitPct = s.SplitPercentage ?? 0;

            // Add this split percentage to the user's total
            // (handles cases where a user has multiple splits on the same opportunity)
            Decimal total = current + splitPct;

            // Cap at 100% if the summed percentage exceeds 100
            oppMap.put(s.SplitOwnerId, total > 100 ? 100 : total);
        }

        // Fallback: If an opportunity has no revenue splits, assign 100% to the opportunity owner
        for (Opportunity o : [SELECT Id, OwnerId FROM Opportunity WHERE Id IN :oppIds]) {
            if (!byOpp.containsKey(o.Id) || byOpp.get(o.Id).isEmpty()) {
                byOpp.put(o.Id, new Map<Id, Decimal>{ o.OwnerId => 100 });
            }
        }

        return byOpp;
    }

    // Computes tier lines for each opportunity and returns only those that have changed
    private static List<Tier__c> computeTierLines(
        Map<Id, Opportunity> oppMap,
        Map<Id, Account> accMap,
        Map<Id, List<OpportunityLineItem>> oliByOpp,
        Map<Id, Map<Id, Decimal>> splitsByOpp,
        Map<Id, Map<Id, Tier__c>> existingLinesByOpp,
        Date asOfDate
    ) {
        List<Tier__c> tierLinesToUpsert = new List<Tier__c>();
        List<Tier__c> tierLinesToDelete = new List<Tier__c>();
        Map<Id, TierCalcEngine.Result> resultsByOppId = new Map<Id, TierCalcEngine.Result>();

        for (Id oppId : oppMap.keySet()) {
            Opportunity opp = oppMap.get(oppId);
            Account acc = (opp.AccountId != null) ? accMap.get(opp.AccountId) : null;
            List<OpportunityLineItem> lines = oliByOpp.containsKey(oppId) ? oliByOpp.get(oppId) : new List<OpportunityLineItem>();
            Map<Id, Decimal> splits = splitsByOpp.get(oppId);

            TierCalcEngine.Result res = TierCalcEngine.compute(opp, acc, lines, splits, asOfDate);

            // Store result for later Opportunity update
            resultsByOppId.put(oppId, res);

            // Get existing lines for this opportunity
            Map<Id, Tier__c> existingCommLinesByUser = existingLinesByOpp.containsKey(oppId)
                ? existingLinesByOpp.get(oppId)
                : new Map<Id, Tier__c>();

            // Track which users are in the new calculation
            Set<Id> newUserIds = new Set<Id>();
            for (Tier__c line : res.lines) {
                newUserIds.add(line.User__c);
            }

            // Only add lines that have changed
            for (Tier__c line : res.lines) {
                Tier__c prev = existingCommLinesByUser.get(line.User__c);
                if (prev == null || prev.Input_Hash__c != line.Input_Hash__c) {
                    tierLinesToUpsert.add(line);
                }
            }

            // Mark for deletion: existing lines for users no longer in splits
            for (Id existingUserId : existingCommLinesByUser.keySet()) {
                if (!newUserIds.contains(existingUserId)) {
                    tierLinesToDelete.add(existingCommLinesByUser.get(existingUserId));
                }
            }
        }

        // Delete obsolete tier lines first
        if (!tierLinesToDelete.isEmpty()) {
            System.debug('Deleting obsolete tier lines: ' + tierLinesToDelete.size() + ' lines: ' + tierLinesToDelete);
            delete tierLinesToDelete;
        }

        // Upsert changed tier lines
        if (!tierLinesToUpsert.isEmpty()) {
            System.debug('Upserting tier lines (size): ' + tierLinesToUpsert.size() + ' lines: ' + tierLinesToUpsert);
            upsert tierLinesToUpsert Line_Key__c; // External ID + Unique
        }

        // Update Opportunity T2 and T3 V2 fields if values have changed
        updateOpportunityTierFields(oppMap, resultsByOppId);

        return tierLinesToUpsert;
    }

    // Updates Total_Amount_T2__c and Total_Amount_T3__c on Opportunities if values have changed
    private static void updateOpportunityTierFields(
        Map<Id, Opportunity> oppMap,
        Map<Id, TierCalcEngine.Result> resultsByOppId
    ) {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Id oppId : resultsByOppId.keySet()) {
            Opportunity opp = oppMap.get(oppId);
            TierCalcEngine.Result res = resultsByOppId.get(oppId);

            Boolean needsUpdate = false;
            Opportunity oppUpdate = new Opportunity(Id = oppId);

            // Update T2 only if not manually overridden
            if (opp.T2_Override__c != true) {
                // Rounded to 2 decimal places to match database storage
                Decimal roundedT2 = (res.t2calc != null) ? res.t2calc.setScale(2, RoundingMode.HALF_UP) : 0;
                if (opp.Total_Amount_T2__c != roundedT2) {
                    oppUpdate.Total_Amount_T2__c = roundedT2;
                    needsUpdate = true;
                }
            }

            // Update T3 only if not manually overridden
            if (opp.T3_Override__c != true) {
                // Rounded to 2 decimal places to match database storage
                Decimal roundedT3 = (res.t3calc != null) ? res.t3calc.setScale(2, RoundingMode.HALF_UP) : 0;
                if (opp.Total_Amount_T3__c != roundedT3) {
                    oppUpdate.Total_Amount_T3__c = roundedT3;
                    needsUpdate = true;
                }
            }

            if (needsUpdate) {
                oppsToUpdate.add(oppUpdate);
            }
        }

        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }
    }
}