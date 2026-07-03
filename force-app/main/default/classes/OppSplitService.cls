/**
 * Shared utility for Opportunity Split automation.
 *
 * Responsibility:
 *   - cache OpportunitySplitType Ids for T1 / T2 / T3
 *   - build deduplication keys for OpportunitySplit records
 */
public without sharing class OppSplitService {

    private static Map<String, Id> splitTypeIdsByLabel;
    private static AutomationSettings__c settings;
    private static Boolean automationRunning = false;

    // Recursion guard for the OppSplit automation block.
    public static Boolean tryEnterAutomation() {
        if (automationRunning) {
            return false;
        }
        automationRunning = true;
        return true;
    }

    // Used only in unit tests to allow multiple trigger-relevant DML operations within the same test method
    @TestVisible
    private static void resetAutomationFlag() {
        automationRunning = false;
    }

    @TestVisible
    private static void clearAutomationSettingsCache() {
        settings = null;
    }

    // Closed opportunities skip T1/T2/T3 assignment and owner-change logic.
    // Exception: Run_Splits_Flow__c (admin repair) is allowed to run on closed opportunities.
    public static Boolean isClosed(Opportunity opp) {
        return opp.IsClosed;
    }

    // Checks if standard Opportunity Split automation is enabled.
    public static Boolean isAutomationEnabled() {
        if (settings == null) {
            settings = AutomationSettings__c.getInstance();
        }
        return settings != null && settings.Automation_Enabled__c == true;
    }

    // Generic query for OpportunitySplits by Opportunity IDs and Split Type IDs.
    public static List<OpportunitySplit> getSplits(Set<Id> oppIds, Set<Id> splitTypeIds) {
        if (oppIds.isEmpty() || splitTypeIds.isEmpty()) {
            return new List<OpportunitySplit>();
        }
        return [
            SELECT Id, OpportunityId, SplitTypeId
            FROM OpportunitySplit
            WHERE OpportunityId IN :oppIds AND SplitTypeId IN :splitTypeIds
        ];
    }

    public static Id getSplitTypeId(String splitLabel) {
        loadSplitTypeIds();
        return splitTypeIdsByLabel.get(splitLabel);
    }

    public static Map<String, Id> getSplitTypeIdsByLabel() {
        loadSplitTypeIds();
        return new Map<String, Id>(splitTypeIdsByLabel);
    }

    public static String buildKey(Id oppId, Id ownerId) {
        return (String) oppId + '_' + (String) ownerId;
    }

    public static String buildKey(Id oppId, Id ownerId, Id splitTypeId) {
        return (String) oppId + '_' + (String) ownerId + '_' + (String) splitTypeId;
    }

    // Shared helper to build and add an OpportunitySplit record to a target list if it does not already exist.
    public static void addSplitIfMissing(
        List<OpportunitySplit> targetList,
        Set<String> existingKeys,
        Id oppId,
        Id ownerId,
        Id splitTypeId
    ) {
        String key = buildKey(oppId, ownerId, splitTypeId);
        if (!existingKeys.contains(key)) {
            targetList.add(new OpportunitySplit(
                OpportunityId   = oppId,
                SplitOwnerId    = ownerId,
                SplitPercentage = 100,
                SplitTypeId     = splitTypeId
            ));
            existingKeys.add(key);
        }
    }

    // Standardized logic to ensure both Opp Owner and Account Owner have 100% splits for a given tier if they qualify.
    public static void createStandardSplits(
        List<OpportunitySplit> splitsToCreate,
        Map<Id, Opportunity> oppMap,
        List<Id> qualifyingOppIds,
        Id splitTypeId,
        Set<String> existingKeys
    ) {
        for (Id oppId : qualifyingOppIds) {
            Opportunity opp = oppMap.get(oppId);
            if (opp == null) continue;

            // Opp Owner split
            addSplitIfMissing(splitsToCreate, existingKeys, oppId, opp.OwnerId, splitTypeId);

            // Account Owner split — only when different from Opp Owner
            Id accountOwnerId = populatedAccountOwnerId(opp);
            if (accountOwnerId != null && accountOwnerId != opp.OwnerId) {
                addSplitIfMissing(splitsToCreate, existingKeys, oppId, accountOwnerId, splitTypeId);
            }
        }
    }

    private static Id populatedAccountOwnerId(Opportunity opp) {
        return opp.Account != null ? opp.Account.OwnerId : null;
    }

    private static void loadSplitTypeIds() {
        if (splitTypeIdsByLabel == null) {
            splitTypeIdsByLabel = new Map<String, Id>();
            for (OpportunitySplitType splitType : [
                SELECT Id, MasterLabel
                FROM OpportunitySplitType
                WHERE MasterLabel IN ( 'T1', 'T2', 'T3')
            ]) {
                splitTypeIdsByLabel.put(splitType.MasterLabel, splitType.Id);
            }
        }
    }
}