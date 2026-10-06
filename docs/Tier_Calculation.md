# Tier calculation

`TierCalcEngine` turns Opportunity Products into a T2 amount and a T3 amount. `TierCalcService` writes one `Tier__c` row per split user and, unless a manual override is on, writes those totals back to the Opportunity. The scheduled batch `TierCalcScheduledJob` runs that for Opportunities modified in the last 24 hours. The screen flow **Calculate Tiers** runs it for one Opportunity.

T1 on the tier line is T2 plus T3. It is not a third product formula.

Those Opportunity totals are also what [T1, T2, and T3 opportunity splits](Opportunity_Splits.md) use to decide whether T2 and T3 split rows should exist. Saving `Total_Amount_T2__c` or `Total_Amount_T3__c` is an Opportunity update, so the split engine runs in the same transaction when automation is on.

---

## Table of Contents

1. [What gets written](#what-gets-written)
2. [Who is on the tier line](#who-is-on-the-tier-line)
3. [T2 amount](#t2-amount)
4. [T3 amount](#t3-amount)
5. [Overrides](#overrides)
6. [Scheduled job](#scheduled-job)
7. [Calculate Tiers flow](#calculate-tiers-flow)
8. [UK and US flows that still write amounts](#uk-and-us-flows-that-still-write-amounts)

---

## What gets written

`Tier__c` (label **Tier**, name `TR-{000000}`) is one row per Opportunity and user.

| Field | Value |
| --- | --- |
| `Line_Key__c` | `{OpportunityId}:{UserId}`. Unique external id. Upsert key. |
| `Opportunity__c`, `Account__c`, `User__c` | The Opportunity, its Account, and the split user |
| `CurrencyIsoCode` | The Opportunity currency |
| `Status__c` | `Calculated`. The picklist also has Draft and Locked. The calculator does not read status, so a later recalc overwrites Locked as well. |
| `T2_Amount__c` | The Opportunity T2 total |
| `T3_Amount__c` | The Opportunity T3 total |
| `T1_Amount__c` | T2 plus T3 |
| `Input_Snapshot__c` | JSON of the Opportunity id, Account id, user id, the three totals, and the full split map |
| `Input_Hash__c` | SHA1 of that JSON |

Every user on the Opportunity gets the same three amounts. The split percentage is stored in the snapshot and affects the hash. It is not multiplied into `T1_Amount__c`, `T2_Amount__c`, or `T3_Amount__c`.

A line is upserted only when it is new or the hash changed. A line whose user is no longer in the split map is deleted.

`calculateFor` takes an `asOfDate`. `TierCalcEngine.compute` does not read it. Callers pass `Date.today()`.

On the Opportunity, when the value would change:

| Field | Written when |
| --- | --- |
| `Total_Amount_T2__c` | `T2_Override__c` is not true. Rounded half-up to 2 decimal places. Null result is stored as 0. |
| `Total_Amount_T3__c` | `T3_Override__c` is not true. Same rounding. |

`T3_From_Products__c` is set on the Opportunity variable inside `calculateT3` and is not included in that update. `T2_Attainment_Amount__c` is calculated on each product in memory and is not saved back to the product. The UK/US flows below are what still persist those two fields.

---

## Who is on the tier line

`loadOpportunitySplits` reads every `OpportunitySplit` on the Opportunity, of every split type. For each user it adds `SplitPercentage` across their rows and caps the sum at 100. That cap is only for the snapshot. The amount fields stay the full totals.

If the Opportunity has no splits, the Opportunity owner is used at 100% so one tier line is still created.

---

## T2 amount

If `T2_Override__c` is true, T2 is the current `Total_Amount_T2__c` (or 0 when that field is null). Products are not summed.

If the Opportunity has no products, T2 is `Estimate_Consulting_Revenue__c` plus `Estimate_Managed_Service_Revenue__c`. Null estimates count as 0.

If it has products, T2 is the sum of each product's attainment amount. Attainment is calculated as follows. `Revenue_Type_Formula__c` and `Renewal__c` come from the product. The project date is `Opportunity.Project_Start_Date_From_Project__c`.

1. Blank revenue type, or revenue type `Licenses`: attainment is 0.
2. Otherwise, `Renewal__c` of `New` or `Upgrade (Same Platform)`: attainment is `Total_List_Price_Incl_Discount__c`.
3. Otherwise, no project start date: attainment is 0.
4. License start is after project start plus 365 days: attainment is 0.
5. License end is before project start plus 365 days: attainment is the full `Total_List_Price_Incl_Discount__c`.
6. Otherwise, when license start and `days__c` are set and `days__c` is greater than 0:

   `(license start → project start + 365 days) / days__c × Total_List_Price_Incl_Discount__c`

7. Anything else: 0.

A null list price counts as 0. Products with attainment 0 are not added.

---

## T3 amount

If `T3_Override__c` is true, T3 is the current `Total_Amount_T3__c` (or 0 when null).

If the Opportunity has no products, T3 is `Estimate_Licensing_GP__c` (Estimate: Licensing Margin), or 0 when that field is null.

If it has products, T3 is:

`sum of Margin_Value__c on products where T3_Product__c is true`

plus `Deal_Reg_Rebate_Value_Currency__c`

plus `Atlassian_PVR_Rebate_Currency__c`

Null margins and null rebates count as 0. The product margin sum is what the engine keeps as `T3_From_Products__c` in memory.

---

## Overrides

| Checkbox | Effect in Apex |
| --- | --- |
| `T2_Override__c` | `calculateT2` returns the stored T2 total. The Opportunity field is not updated. |
| `T3_Override__c` | `calculateT3` returns the stored T3 total. The Opportunity field is not updated. |

Tier lines are still upserted. They show those stored totals. Unchecking an override does not by itself launch a flow for T2 (`T2_Override_set_to_false` is Obsolete). The next tier recalc writes a new T2. T3 Override becoming false on a UK or US Opportunity also starts `T3_Roll_Up`. See [UK and US flows](#uk-and-us-flows-that-still-write-amounts).

---

## Scheduled job

`TierCalcScheduledJob` is batchable and schedulable. `execute(SchedulableContext)` starts the batch at scope 200.

The default query is Opportunities whose `LastModifiedDate` is within the last 24 hours, newest first. Constructors:

| Constructor | Query |
| --- | --- |
| `new TierCalcScheduledJob()` | Last 24 hours |
| `new TierCalcScheduledJob(hours)` | Last *hours* hours |
| `new TierCalcScheduledJob(oppIds)` | Those ids only |

Each scope calls `TierCalcService.calculateFor(oppIds, Date.today())`. One exception fails the whole scope. Those Opportunities are counted as errors and are not retried inside the job.

`finish` emails only when at least one scope failed. Recipients are the addresses and active users on **Apex Exception Email** (`ApexEmailNotification`). The sender is an org-wide email address with **Allow All Profiles** when one exists. The subject is `Tier Calculation Batch Job - Errors Detected`. No recipients means no email.

`TierCalcScheduledJob.schedule(jobName, cron)` schedules it. The class comment's daily example is job name `Daily Tier Calc`, cron `0 0 0 * * ?` (midnight in the org timezone, `Europe/Helsinki`). `abortAll` aborts cron jobs whose name contains `TierCalc`.

There is no Lightning component for this. `TierCalcController.recalcNow` and `getTierLines` are Aura methods. Nothing in `lwc` calls them. The screen flow below uses the invocable method.

---

## Calculate Tiers flow

`Calculate_Tiers` (label **Calculate Tiers**) is an **Active** screen flow. It takes an Opportunity (`recordId`) and immediately calls the invocable **Recalculate Tiers** (`TierCalcController.recalculateTiers`) for that one id.

The screen then says the tiers were recalculated and prints the line list, or prints the exception message when the call failed. The finish button is **Close**.

The same invocable can be dropped into another flow. It returns success, message, the line list, and the line count.

---

## UK and US flows that still write amounts

`TierCalcEngine` comments name the flows it was taken from. Several of those flows are still **Active**, and they only run for Account subsidiary UK or US, with `AutomationSettings__c.Automation_Enabled__c` true. Apex recalculates totals for every Opportunity the batch selects, not only UK and US.

| Flow | Still does |
| --- | --- |
| `T2_Amount_Calculation_Launch_Roll_Ups` | On Opportunity Product create or update, when Quotas Update Allowed is true and a price, discount, date, renewal, or revenue-type field changed, writes `T2_Attainment_Amount__c`. |
| `Calculate_T2_Amount_Roll_Up_from_Opportunity` | Same product field. Called when the related project changes, or when that project's start date changes. |
| `T3_Roll_Up` | Sums `Margin_Value__c` for `T3_Product__c` products when T3 Override is false, and writes `T3_From_Products__c`. It does not write `Total_Amount_T3__c`. Called by `T3_Override_set_to_false` when an update makes that checkbox false. |
| `T3_Roll_Up_Product_Deleted` and `T2_T3_Roll_Ups_when_product_is_deleted` | Active autolaunched flows. The record-triggered flow that called them on product delete is Obsolete, so nothing active starts them. |

The batch's T2 total uses the attainment formula in memory, including for subsidiaries other than UK and US, where the product field may never have been written. The batch's T3 total includes the two rebate fields. `T3_Roll_Up` does not add those rebates onto `T3_From_Products__c`.
