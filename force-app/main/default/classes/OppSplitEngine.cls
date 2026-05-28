/**
 * Logic Engine for Opportunity Split automation.
 * Contains business rules for T1, T2, and T3 split creation and management.
 */
public without sharing class OppSplitEngine {

    /**
     * Optimized single-pass execution for all Opportunity Split logic.
     */
    public static void execute(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Set<Id> allCandidateIds = new Set<Id>();
        for (Opportunity opp : newList) {
            if (opp.Id != null) allCandidateIds.add(opp.Id);
        }

        // Shared context and split data
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
            SELECT Id, OwnerId, AccountId, T1_Opp__c, Total_Amount_T2__c, Total_Amount_T3__c,
                   CloseDate, Run_Splits_Flow__c, Net_Revenue_Forecast__c,
                   Estimate_Managed_Service_Revenue__c, Estimate_Licensing_Revenue__c,
                   T3_From_Products__c, Quota_Update_Allowed__c,
                   Account.OwnerId, Account.T1_Start_Date__c
            FROM Opportunity
            WHERE Id IN :allCandidateIds
        ]);
        Map<String, Id> typeIds = OppSplitService.getSplitTypeIdsByLabel();

        // Build a map of the new records for fast lookup by Id
        Map<Id, Opportunity> newOppsMap = new Map<Id, Opportunity>();
        for (Opportunity opp : newList) {
            if (opp.Id != null) newOppsMap.put(opp.Id, opp);
        }

        List<OpportunitySplit> existingSplits = [
                SELECT Id, OpportunityId, SplitOwnerId, SplitTypeId, SplitPercentage
                FROM OpportunitySplit
                WHERE OpportunityId IN :allCandidateIds AND SplitTypeId IN :typeIds.values()
        ];

        Set<String> existingKeys = new Set<String>();
        for (OpportunitySplit s : existingSplits) {
            existingKeys.add(OppSplitService.buildKey(s.OpportunityId, s.SplitOwnerId, s.SplitTypeId));
        }

        SplitDmlBuffer cs = new SplitDmlBuffer();

        for (Opportunity opp : newList) {
            // Use Trigger.new record for fields, but populated record for relations
            Opportunity populated = oppMap.get(opp.Id);
            if (populated == null) {
                // For uninserted records in tests, we skip if we can't find them in DB,
                // but in a real trigger populated will always be found in after events.
                continue;
            }
            Opportunity old = oldMap != null ? oldMap.get(opp.Id) : null;

            // 1. Admin Repair
            if (opp.Run_Splits_Flow__c == true && (old == null || old.Run_Splits_Flow__c != true) && !OppSplitService.isClosed(opp)) {
                processAdminRepair(opp, populated, existingKeys, cs, typeIds);
                cs.oppsToUpdate.put(opp.Id, new Opportunity(Id = opp.Id, Run_Splits_Flow__c = false));
            }

            // 2. T1/T2/T3 Assignments
            if (!OppSplitService.isClosed(opp) && opp.Quota_Update_Allowed__c == true) {
                // T1
                if (t1IsQualifying(opp, old)) {
                    processT1(opp, populated, existingKeys, cs, typeIds.get('T1'));
                }
                // T2
                if (t2IsQualifying(opp, old)) {
                    processT2(opp, populated, existingKeys, cs, typeIds.get('T2'));
                }
                // T3
                if (t3IsQualifying(opp, old)) {
                    processT3(opp, populated, existingKeys, cs, typeIds.get('T3'));
                }

                // T1 Date Gate status update
                if (old != null && (opp.CloseDate != old.CloseDate || opp.AccountId != old.AccountId)) {
                    processT1WindowGateStatus(opp, populated, cs);
                }

                // Owner Change status update
                if (old != null && opp.OwnerId != old.OwnerId) {
                    processOwnerChangeStatus(opp, populated, existingSplits, existingKeys, cs, typeIds);
                }
            }
        }

        // 3. Global Deletion Pass
        processDeletions(existingSplits, newOppsMap, oppMap, oldMap, cs, typeIds);

        // Execute DML
        applyChanges(cs);
    }

    private static void processAdminRepair(Opportunity opp, Opportunity populated, Set<String> existingKeys, SplitDmlBuffer cs, Map<String, Id> typeIds) {
        Id oppOwner = opp.OwnerId;
        Id accOwner = populated.Account != null ? populated.Account.OwnerId : null;
        Boolean diff = accOwner != null && accOwner != oppOwner;

        for (String label : new List<String>{'T1', 'T2', 'T3'}) {
            Id typeId = typeIds.get(label);
            Boolean eligible = (label == 'T1' && opp.T1_Opp__c == 'Yes') ||
                               (label == 'T2' && opp.Total_Amount_T2__c != null && opp.Total_Amount_T2__c != 0) ||
                               (label == 'T3' && opp.Total_Amount_T3__c != null && opp.Total_Amount_T3__c != 0);
            if (eligible) {
                OppSplitService.addSplitIfMissing(cs.toInsert, existingKeys, opp.Id, oppOwner, typeId);
                if (diff) OppSplitService.addSplitIfMissing(cs.toInsert, existingKeys, opp.Id, accOwner, typeId);
            }
        }
    }

    private static void processT1(Opportunity opp, Opportunity populated, Set<String> existingKeys, SplitDmlBuffer cs, Id typeId) {
        Date t1Start = populated.Account != null ? populated.Account.T1_Start_Date__c : null;
        if (t1Start != null && opp.CloseDate >= t1Start) {
            addStandardSplitsLocally(opp, populated, existingKeys, cs, typeId);
            if (opp.T1_Opp__c != 'Yes') cs.oppsToUpdate.put(opp.Id, new Opportunity(Id = opp.Id, T1_Opp__c = 'Yes'));
        }
    }

    private static void processT2(Opportunity opp, Opportunity populated, Set<String> existingKeys, SplitDmlBuffer cs, Id typeId) {
        addStandardSplitsLocally(opp, populated, existingKeys, cs, typeId);
    }

    private static void processT3(Opportunity opp, Opportunity populated, Set<String> existingKeys, SplitDmlBuffer cs, Id typeId) {
        addStandardSplitsLocally(opp, populated, existingKeys, cs, typeId);
    }

    private static void addStandardSplitsLocally(Opportunity opp, Opportunity populated, Set<String> existingKeys, SplitDmlBuffer cs, Id typeId) {
        OppSplitService.addSplitIfMissing(cs.toInsert, existingKeys, opp.Id, opp.OwnerId, typeId);
        Id accOwnerId = populated.Account != null ? populated.Account.OwnerId : null;
        if (accOwnerId != null && accOwnerId != opp.OwnerId) {
            OppSplitService.addSplitIfMissing(cs.toInsert, existingKeys, opp.Id, accOwnerId, typeId);
        }
    }

    private static void processT1WindowGateStatus(Opportunity opp, Opportunity populated, SplitDmlBuffer cs) {
        Date t1Start = populated.Account != null ? populated.Account.T1_Start_Date__c : null;
        if ((t1Start == null || opp.CloseDate < t1Start) && opp.T1_Opp__c == 'Yes') {
            cs.oppsToUpdate.put(opp.Id, new Opportunity(Id = opp.Id, T1_Opp__c = 'No'));
        }
    }

    private static void processOwnerChangeStatus(Opportunity opp, Opportunity populated, List<OpportunitySplit> existingSplits, Set<String> existingKeys, SplitDmlBuffer cs, Map<String, Id> typeIds) {
        Id accOwnerId = populated != null && populated.Account != null ? populated.Account.OwnerId : null;
        if (accOwnerId != null && accOwnerId != opp.OwnerId) {
            if (opp.T1_Opp__c == 'Yes') {
                OppSplitService.addSplitIfMissing(cs.toInsert, existingKeys, opp.Id, accOwnerId, typeIds.get('T1'));
            }
            if (opp.Total_Amount_T2__c != null && opp.Total_Amount_T2__c != 0) {
                OppSplitService.addSplitIfMissing(cs.toInsert, existingKeys, opp.Id, accOwnerId, typeIds.get('T2'));
            }
            if (opp.Total_Amount_T3__c != null && opp.Total_Amount_T3__c != 0) {
                OppSplitService.addSplitIfMissing(cs.toInsert, existingKeys, opp.Id, accOwnerId, typeIds.get('T3'));
            }
        }
        for (OpportunitySplit s : existingSplits) {
            Boolean isMatchingSplit = s.OpportunityId == opp.Id && accOwnerId != null && opp.OwnerId == accOwnerId &&
                                    s.SplitOwnerId == opp.OwnerId && s.SplitPercentage != 100;
            if (isMatchingSplit) {
                OpportunitySplit clone = s.clone(true, true, true, true);
                clone.SplitPercentage = 100;
                cs.toUpdate.add(clone);
            }
        }
    }

    private static void processDeletions(List<OpportunitySplit> existingSplits, Map<Id, Opportunity> newOppsMap, Map<Id, Opportunity> oppMap, Map<Id, Opportunity> oldMap, SplitDmlBuffer cs, Map<String, Id> typeIds) {
        Id t1TypeId = typeIds.get('T1');
        Id t2TypeId = typeIds.get('T2');
        Id t3TypeId = typeIds.get('T3');

        for (OpportunitySplit s : existingSplits) {
            Opportunity current = newOppsMap.get(s.OpportunityId);
            if (current == null) continue;
            if (current.Quota_Update_Allowed__c != true) continue;
            Opportunity populated = oppMap.get(s.OpportunityId);
            Opportunity old = oldMap != null ? oldMap.get(s.OpportunityId) : null;

            // A. Stale Owner Cleanup
            Id accOwnerId = populated != null && populated.Account != null ? populated.Account.OwnerId : null;
            if (s.SplitOwnerId != current.OwnerId && (accOwnerId == null || s.SplitOwnerId != accOwnerId)) {
                cs.toDelete.add(s);
                continue;
            }

            // B. T1 Disable (Close Date outside window)
            Date t1Start = populated != null && populated.Account != null ? populated.Account.T1_Start_Date__c : null;
            if (s.SplitTypeId == t1TypeId && (t1Start == null || current.CloseDate < t1Start)) {
                cs.toDelete.add(s);
                continue;
            }

            // C. Field-based Deletions (only if fields changed or explicitly reset)
            if (s.SplitTypeId == t1TypeId) {
                Boolean t1FieldChanged = old != null && (old.T1_Opp__c != current.T1_Opp__c || old.Net_Revenue_Forecast__c != current.Net_Revenue_Forecast__c);
                Boolean t1Zero = current.T1_Opp__c != 'Yes' || current.Net_Revenue_Forecast__c == null || current.Net_Revenue_Forecast__c == 0;
                if (t1FieldChanged && t1Zero) cs.toDelete.add(s);
            } else if (s.SplitTypeId == t2TypeId) {
                Boolean t2Zero = current.Total_Amount_T2__c == null || current.Total_Amount_T2__c == 0;
                if (t2Zero) cs.toDelete.add(s);
            } else if (s.SplitTypeId == t3TypeId) {
                Boolean t3Zero = current.Total_Amount_T3__c == null || current.Total_Amount_T3__c == 0;
                if (t3Zero) cs.toDelete.add(s);
            }
        }
    }

    private static void applyChanges(SplitDmlBuffer cs) {
        if (!cs.toDelete.isEmpty()) delete cs.toDelete;
        if (!cs.toInsert.isEmpty()) insert cs.toInsert;
        if (!cs.toUpdate.isEmpty()) update cs.toUpdate;
        if (!cs.oppsToUpdate.isEmpty()) {
            update cs.oppsToUpdate.values();
        }
    }

    private static Boolean t1IsQualifying(Opportunity opp, Opportunity old) {
        if (old == null) {
            return (opp.Amount != null && opp.Amount != 0) ||
                   (opp.Net_Revenue_Forecast__c != null && opp.Net_Revenue_Forecast__c != 0) ||
                   (opp.Estimate_Licensing_Revenue__c != null && opp.Estimate_Licensing_Revenue__c != 0);
        }

        Boolean amountStarted = (old.Amount == null || old.Amount == 0) && (opp.Amount != null && opp.Amount != 0);
        Boolean revenueStarted = (old.Net_Revenue_Forecast__c == null || old.Net_Revenue_Forecast__c == 0) && (opp.Net_Revenue_Forecast__c != null && opp.Net_Revenue_Forecast__c != 0);
        Boolean licensingStarted = (old.Estimate_Licensing_Revenue__c == null || old.Estimate_Licensing_Revenue__c == 0) && (opp.Estimate_Licensing_Revenue__c != null && opp.Estimate_Licensing_Revenue__c != 0);

        return opp.CloseDate != old.CloseDate ||
               opp.AccountId != old.AccountId ||
               amountStarted ||
               revenueStarted ||
               licensingStarted;
    }

    private static Boolean t2IsQualifying(Opportunity opp, Opportunity old) {
        Boolean hasAmount  = opp.Amount != null && opp.Amount != 0;
        Boolean hasMSR     = opp.Estimate_Managed_Service_Revenue__c != null && opp.Estimate_Managed_Service_Revenue__c != 0;
        Boolean hasT2      = opp.Total_Amount_T2__c != null && opp.Total_Amount_T2__c != 0;

        if (!hasAmount && !hasMSR) return false;   // no service revenue at all
        if (hasAmount && !hasT2)   return false;   // amount set but T2 not allocated yet

        if (old == null) return true;

        Boolean amountChanged  = old.Total_Amount_T2__c != opp.Total_Amount_T2__c;
        Boolean accountChanged = old.AccountId != opp.AccountId;
        Boolean serviceStarted = (old.Estimate_Managed_Service_Revenue__c == null || old.Estimate_Managed_Service_Revenue__c == 0) && hasMSR;

        return amountChanged || accountChanged || serviceStarted;
    }


    private static Boolean t3IsQualifying(Opportunity opp, Opportunity old) {
        if (old == null) return opp.Total_Amount_T3__c != null && opp.Total_Amount_T3__c != 0;

        Boolean productsChanged = old.T3_From_Products__c != opp.T3_From_Products__c;
        Boolean amountChanged = opp.Total_Amount_T3__c != null && opp.Total_Amount_T3__c != 0 && old.Total_Amount_T3__c != opp.Total_Amount_T3__c;
        Boolean accountChanged = old.AccountId != opp.AccountId;

        return productsChanged || amountChanged || accountChanged;
    }

    private class SplitDmlBuffer {
        final List<OpportunitySplit> toInsert = new List<OpportunitySplit>();
        final List<OpportunitySplit> toDelete = new List<OpportunitySplit>();
        final List<OpportunitySplit> toUpdate = new List<OpportunitySplit>();
        final Map<Id, Opportunity> oppsToUpdate = new Map<Id, Opportunity>();
    }
}