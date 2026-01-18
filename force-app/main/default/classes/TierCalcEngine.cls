public with sharing class TierCalcEngine {
    public enum Bucket { T1, T2 }

    // Renewal type constants
    public static final String RENEWAL_NEW = 'New';
    public static final String RENEWAL_UPGRADE = 'Upgrade (Same Platform)';

    // Revenue type constants
    public static final String REVENUE_CONSULTING = 'Consulting';
    public static final String REVENUE_MANAGED_SERVICES = 'Managed Services';
    public static final String REVENUE_LICENSES = 'Licenses';

    public class Result {
        public List<Tier__c> lines = new List<Tier__c>();
        public Decimal t1calc = 0;
        public Decimal t2calc = 0;
        public Decimal t3calc = 0;
    }

    public static Result compute(
        Opportunity opp,
        Account acc,
        List<OpportunityLineItem> olis,
        List<Project__c> projects,
        Map<Id,Decimal> splits, // UserId → %
        Date asOfDate
    ){
        Result r = new Result();
        if (splits == null || splits.isEmpty()) splits = new Map<Id, Decimal>{ opp.OwnerId => 100 };

        for (OpportunityLineItem oli : olis) {
            // flow: Calculate_T2_Amount_Roll_Up_from_Opportunity
//            System.debug('oli.T2_Attainment_Amount__c (before):' + oli.T2_Attainment_Amount__c);
            oli.T2_Attainment_Amount__c = calculateT2AttainmentAmount(oli, projects);
//            System.debug('oli.T2_Attainment_Amount__c (after):' + oli.T2_Attainment_Amount__c);
        }

        r.t2calc = calculateT2(opp, olis);
        r.t3calc = calculateT3(opp, olis);
        System.debug('r.t2calc: ' + r.t2calc);
        System.debug('r.t3calc: ' + r.t3calc);
        r.t1calc = r.t2calc + r.t3calc;

        // Distribute per user
        for (Id userId : splits.keySet()) {
            Tier__c line = new Tier__c();
            line.Opportunity__c = opp.Id;
            line.Account__c = opp.AccountId;
            line.User__c = userId;
            line.CurrencyIsoCode = opp.CurrencyIsoCode;
            line.Status__c = 'Calculated';
            line.T1_Amount__c = r.t1calc;
            line.T2_Amount__c = r.t2calc;
            line.T3_Amount__c = r.t3calc;

            // key + snapshot + hash
            String monthKey = DateTime.newInstance(asOfDate, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM');
            line.Line_Key__c = opp.Id + ':' + userId + ':' + monthKey;

            Map<String,Object> snap = new Map<String,Object>{
                'oppId' => opp.Id,
                'accId' => opp.AccountId,
                'userId' => userId,
                'tiers' => new Map<String,Object>{ 't1'=>r.t1calc, 't2'=>r.t2calc, 't3'=>r.t3calc },
                'splits' => splits
            };
            line.Input_Snapshot__c = JSON.serialize(snap);
            line.Input_Hash__c = sha1Hex(line.Input_Snapshot__c);

            r.lines.add(line);
        }
        return r;
    }

    /**
     * flow: Launch_Roll_Ups (T2 portion)
     * Calculates T2 amounts from OpportunityLineItems.
     * In original flow it updates opp.Total_Amount_T2__c with returned value
     *
     * If Total_Amount__c is 0 or null, applies fallback logic based on Estimate_Consulting_Revenue__c
     * and Estimate_Managed_Service_Revenue__c fields.
     */
    public static Decimal calculateT2(Opportunity opp, List<OpportunityLineItem> olis) {
        System.debug('calculateT2 start');
        if (opp == null) {
            return 0;
        }

        // we can add condition 'if opp.Total_Amount__c = 0'
        // flow: T2_T3_Estimate
        // flow: T2_T3_Amounts_from_opportunity_when_Launch_Estimate_Flow_is_checked
        if (olis == null || olis.isEmpty()) {
            Decimal estConsultingRev = opp.Estimate_Consulting_Revenue__c ?? 0;
            Decimal estManagedRev = opp.Estimate_Managed_Service_Revenue__c ?? 0;
            return estConsultingRev + estManagedRev;
        }

        Decimal totalT2Amount = 0;
        // Loop through OpportunityLineItems for T2
        for (OpportunityLineItem oli : olis) {
            System.debug('oli.T2_Attainment_Amount__c: ' + oli.T2_Attainment_Amount__c);
            if (oli.T2_Attainment_Amount__c != null && oli.T2_Attainment_Amount__c != 0 && opp.T2_Override__c == false) {
                totalT2Amount += oli.T2_Attainment_Amount__c;
            }
        }
        System.debug('totalT2Amount: ' + totalT2Amount);

        return totalT2Amount;
    }

    /**
     * flow 1: Launch_Roll_Ups (T3 portion)
     * flow 2: T3_Roll_Up_Product_Deleted
     * Calculates T3 amounts from OpportunityLineItems.
     * Original flow (1) updates Total_Amount_T3__c with returned value
     * Original flow (2) updates Total_Amount_T3__c with returned value
     * so Total_Amount_T3__c = return of calculateT3
     */
    public static Decimal calculateT3(Opportunity opp, List<OpportunityLineItem> olis) {
        System.debug('calculateT3 start');
        if (opp == null) {
            return 0;
        }
//        System.debug('olis: ' + olis);

        // we can add condition 'if opp.Total_Amount__c = 0'
        // flow: T2_T3_Estimate
        // flow: T2_T3_Amounts_from_opportunity_when_Launch_Estimate_Flow_is_checked
        if (olis == null || olis.isEmpty()) {
            return opp.Estimate_Licensing_GP__c ?? 0;
        }

        Decimal totalMargin = 0;

        // Loop through OpportunityLineItems for T3
        for (OpportunityLineItem oli : olis) {
//            System.debug('oli: ' + oli);
            if (oli.T3_Product__c == true && opp.T3_Override__c == false) {
                Decimal marginValue = oli.Margin_Value__c ?? 0;
                totalMargin += marginValue;
            }
        }

        // Update Opportunity fields
        opp.T3_From_Products__c = totalMargin;
//        System.debug('totalMargin: ' + totalMargin);

//        not needed if it's not run in trigger context as formula is already calculated
//        List<FormulaRecalcResult> results = Formula.recalculateFormulas(new List<Opportunity>{opp});
//        System.assert(results[0].isSuccess());
//        System.debug('New Deal_Reg_Rebate_Value_Currency__c value: ' + opp.get('Deal_Reg_Rebate_Value_Currency__c'));

        // Calculate Final T3 Amount
        Decimal dealRegRebate = opp.Deal_Reg_Rebate_Value_Currency__c ?? 0;
//        System.debug('dealRegRebate: ' + dealRegRebate);
        return opp.T3_From_Products__c + dealRegRebate;
    }


    /**
     * flow: Calculate_T2_Amount_Roll_Up_from_Opportunity
     * Calculates T2_Attainment_Amount__c for an OpportunityLineItem based on flow conditions.
     * Original flow also updates oli.T2_Attainment_Amount__c
     *
     * Decision Tree (matching Salesforce flow exactly):
     *
     * 1. Revenue_Type Decision:
     *    - If Revenue Type is null/blank OR "Licenses" → T2 = 0
     *    - Otherwise (Consulting or Managed Services) → Continue
     *
     * 2. Product_Type Decision:
     *    - If Renewal = "New" OR "Upgrade (Same Platform)" → T2 = Full Amount
     *    - Otherwise → Continue
     *
     * 3. Has_project Decision:
     *    - If no Related_Project (projectStartDate is null) → T2 = 0
     *    - Otherwise → Continue
     *
     * 4. Date Decision:
     *    - If License_Start_date > (Project_Start_Date + 365) → T2 = 0
     *    - If License_end_date < (Project_Start_Date + 365) → T2 = Full Amount
     *    - Otherwise (In between) → T2 = Prorated Amount
     *      Formula: ((Project_Start_Date + 365 - License_Start_date) / days) * Total_List_Price_Incl_Discount
     */
    private static Decimal calculateT2AttainmentAmount(OpportunityLineItem oli, List<Project__c> projects) {
//        System.debug('oli: ' + oli);
//        System.debug('projects: ' + projects);
        if (oli == null) return 0;

        // Step 1: Check Revenue Type (matches flow "Revenue_Type" decision)
        String revenueType = oli.Revenue_Type_Formula__c;
        String renewal = oli.Renewal__c;

        if (String.isBlank(revenueType)  || revenueType == REVENUE_LICENSES) {
            return 0;
        }

        if (renewal == RENEWAL_NEW || renewal == RENEWAL_UPGRADE) {
            return oli.Total_List_Price_Incl_Discount__c ?? 0;
        }

        // Step 3: Check if project exists (matches flow "Has_project" decision)
        Date projectStartDate = null;
        if (projects != null && !projects.isEmpty()) {
            projectStartDate = projects[0].Project_Start_Date_new__c;
        }

        // If no project → T2 = 0
        if (projectStartDate == null) {
            return 0;
        }

        // Step 4: Date-based decisions (matches flow "Date" decision)
        Date licenseStartDate = oli.License_Start_date__c;
        Date licenseEndDate = oli.License_end_date__c;
        Decimal totalListPriceInclDiscount = oli.Total_List_Price_Incl_Discount__c ?? 0;
        Decimal days = oli.days__c;
        Date projectStartPlus365 = projectStartDate.addDays(365);

        // If License_Start_date > ProjectStartDate+365 → T2 = 0 (After Project Start Date)
        if (licenseStartDate != null && licenseStartDate > projectStartPlus365) {
            return 0;
        }

        // If License_end_date < ProjectStartDate+365 → T2 = Full Amount (Before Project Start Date)
        if (licenseEndDate != null && licenseEndDate < projectStartPlus365) {
            return totalListPriceInclDiscount;
        }

        // Otherwise (In between) → T2 = Prorated Amount
        if (licenseStartDate != null && days != null && days > 0) {
            Decimal daysInPeriod = licenseStartDate.daysBetween(projectStartPlus365);
            return (daysInPeriod / days) * totalListPriceInclDiscount;
        }

        return 0;
    }

    private static String sha1Hex(String input) {
        Blob b = Crypto.generateDigest('SHA1', Blob.valueOf(input == null ? '' : input));
        return EncodingUtil.convertToHex(b);
    }
}