# Automatic monthly invoice import

Accounts on a monthly Atlassian cloud plan can have their paid card invoices imported on a schedule. The job creates an Opportunity per invoice, adds the monthly lines as Opportunity Products, and moves the Opportunity to **Closing** so the existing NetSuite path can pick it up.

Manual import of a single invoice is described in [Quote and invoice import](Quote_And_Invoice_Import.md). Invoice Groups must be linked and active. See [Invoice groups](Invoice_Groups.md).

---

## Table of Contents

1. [What this solves](#what-this-solves)
2. [Which invoices are imported](#which-invoices-are-imported)
3. [Job chain](#job-chain)
4. [Opportunity fields](#opportunity-fields)
5. [Pending invoices](#pending-invoices)
6. [Credential and transaction account](#credential-and-transaction-account)
7. [Product mapping](#product-mapping)
8. [PPC Invoice Auto Import Settings](#ppc-invoice-auto-import-settings)
9. [How to turn it on](#how-to-turn-it-on)
10. [Batch job monitor](#batch-job-monitor)
11. [Troubleshooting](#troubleshooting)

---

## What this solves

License operations previously opened the Atlassian portal for each monthly customer and copied invoice lines onto Opportunities. That work grew with the customer count and was easy to miss or duplicate.

The scheduled job reuses the Commerce API invoice client. It only runs for Accounts that have **Auto Invoice Import** (`AutoInvoiceImport__c`) checked.

---

## Which invoices are imported

`PpcInvoiceImporterBatch` loads Accounts with `AutoInvoiceImport__c = true`, then asks `PortalCommerceApiController.getPaidInvoices` for **paid** invoices on each **active** Invoice Group.

An invoice is imported when all of the following are true:

- Payment method type is `CARD`
- At least one line has `planObj.cycle.interval = MONTHLY`
- `createdAt` is within the last *N* days (`LastDays__c` on the custom setting, default 5)
- No Opportunity on the same Account already has `ImportedInvoiceNumber__c` equal to this invoice number

Other lines on a selected invoice are still mapped by `PpcOpportunityProductMapper`. The CARD + MONTHLY check decides whether the invoice is eligible. It does not drop non-monthly lines off an eligible invoice.

---

## Job chain

```text
PpcInvoiceImporterBatch          (scheduled; also the batch)
        │  creates Opportunity (stage Explore) + PendingInvoice__c (Waiting)
        ▼
InvoiceToOpportunityBatch        (started from the first batch's finish)
        │  re-fetches the invoice, loads entitlement partner info,
        │  maps lines, sets PendingInvoice to Processing
        ▼
ProcessOpportunityLinesQueueable (chains itself)
        │  inserts up to 90 Opportunity Products per execution
        ▼
Opportunity stage = Closing, PendingInvoice status = Done
```

`PpcInvoiceImporterBatch` is schedulable. `execute(SchedulableContext)` calls `run()`. `run()` does nothing if either batch class already has a job in Queued, Preparing, Processing, or Holding.

In Eficode production the job is scheduled and waiting:

| | |
| --- | --- |
| Scheduled job name | `Apex Morning Auto Invoice Import` |
| Apex class | `PpcInvoiceImporterBatch` |
| Cron | `0 45 8 * * ?` |
| When | Every day at 08:45, org timezone `Europe/Helsinki` |

Batch scope is one Account (`PAGE_SIZE = 1`) so callouts for that Account's Invoice Groups stay inside governor limits.

`InvoiceToOpportunityBatch` does not trust a stored JSON body. It calls `PortalCommerceApiController.getInvoice` with the invoice id, then `getEntitlementPartnerInfo` per entitlement, then `PpcOpportunityProductMapper.mapProducts` with merging forced on. Product lookup is `PpcProductToSalesforceMapping__mdt`, the same table as a manual invoice import. See [Product mapping](#product-mapping).

`ProcessOpportunityLinesQueueable` inserts up to 90 lines, updates `LineItemsInserted__c`, and enqueues itself with the remainder. When the list is empty and the pending invoice is not in Error, it sets the Opportunity stage to **Closing** and the pending invoice to **Done**.

The Opportunity is created in stage **Explore**. It moves to **Closing** only after the line items have been inserted.

On that insert, the before-save flow **Set default owner on imported renewal oppty** sets `OwnerId` from `DefaultOpportunityOwner__c` for the Account subsidiary. See [Default Opportunity Owner](Default_Opportunity_Owner.md).

---

## Opportunity fields

Set in `PpcInvoiceImporterBatch.createOpportunity`:

| Field | Value |
| --- | --- |
| `Name` | Account name, abbreviated to 70 characters, plus ` - Monthly - ` plus the invoice number |
| `CloseDate` | Invoice `createdAt` date |
| `StageName` | `Explore`, then `Closing` after lines are inserted |
| `LeadSource` | `Renewal` |
| `ImportedInvoiceNumber__c` | Invoice number (duplicate check) |
| `Atlassian_AT_Quote_ref__c` | Invoice number |
| `Type` | `Customer_Opp` |
| `Monthly_Cloud_Opp__c` | `true` |
| `Special_Instructions_to_Accounts__c` | Copied from the Account |
| `Payment_Terms__c` | `Payment_Terms_Licenses__c` on the Account when set, otherwise `Payment_terms__c` |
| Currency | Account currency, applied by Salesforce |

---

## Pending invoices

`PendingInvoice__c` tracks one invoice through the chain.

| Field | Role |
| --- | --- |
| `Name` | Invoice number |
| `InvoiceId__c` | PPC invoice id used to re-fetch the invoice |
| `Status__c` | `Waiting` → `Processing` → `Done`, or `Error` / `Failed` |
| `Account__c`, `Opportunity__c` | The Account and the new Opportunity |
| `TotalLineItems__c` | Lines the mapper produced |
| `LineItemsInserted__c` | Lines inserted so far |
| `RetryCount__c` | Incremented when insert fails |
| `Error__c` | Last exception message |
| `Subsidiary__c` | Subsidiary, when populated |

`Invoice_JSON__c` through `Invoice_JSON_5__c` exist on the object. The importer currently stores empty strings in those fields and loads the invoice again by id in the next batch.

A lock error on the Opportunity or Account increments `RetryCount__c` and sets status **Error**. After 4 retries the status becomes **Failed** and the queueable stops. The next scheduled run will not create a second Opportunity for the same invoice number, because `ImportedInvoiceNumber__c` is already set. Fix the error, then reprocess that pending invoice or clear the Opportunity reference before expecting another automatic create.

When **Delete pending invoices** is checked, `InvoiceToOpportunityBatch.finish` deletes `PendingInvoice__c` rows in status **Done** older than **Days to keep pending invoices**.

---

## Credential and transaction account

Each Account is called with the named credential for `Account.CV_Subsidiary__c`. That value is looked up on `PPC_TransactionAccount__mdt`:

| Piece | Where it is stored |
| --- | --- |
| Subsidiary API value | `SubsidiaryApiName__c`. Must equal `CV_Subsidiary__c`. Jodocus is `Jodocus GmbH` on the Account and developer name `JODOCUS` on the metadata. |
| Named credential | `Eficode_Office_` plus the metadata developer name. |
| Transaction account UUID | The metadata label. It is the named credential username and the `X-transaction-account` header. |

The full office table is in [Atlassian PPC overview](Atlassian_PPC_Overview.md#subsidiaries-and-transaction-accounts).

`PortalCommerceApiClient` refuses the call unless the **running user** has custom permission `Eficode_Office_{CODE}`. For this job that user is whoever scheduled `PpcInvoiceImporterBatch`. They need the permission for every subsidiary that has **Auto Invoice Import** checked. A missing permission surfaces as `User does not have access to the office`.

---

## Product mapping

The monthly job does not use `PortalProductToSalesforceMapping__mdt`. That table is only for the JSON quote file.

Invoice lines are mapped with `PpcProductToSalesforceMapping__mdt` through `PpcPortalProductMapper`, the same class as a manual Commerce API invoice import. `InvoiceToOpportunityBatch` calls `PpcOpportunityProductMapper.mapProducts(invoice, opportunity, 1.0, null, true)`. The last argument forces **Merge Line Items** on. There is no checkbox on this job.

| Field | How it is used |
| --- | --- |
| `ProductName__c` | Match key. Blank on the default row. |
| `SalesforceProductName__c` | Must equal `Product2.Name`. |

The match key is the invoice line **description** with everything from the first `(` removed, then trimmed. Comparison is case-sensitive.

`Jira, Premium, Annual (USD, Default, 29-03-2024)` matches `ProductName__c` = `Jira, Premium, Annual`.

1. Exactly one metadata row for that name: use its Salesforce product. If no `Product2` has that name, the pending invoice goes to **Error** when the mapper reads the product id. Keep the name identical to `Product2.Name`, and add a price book entry in the Opportunity currency.
2. No row for that name: the line still imports. It uses the blank-name default, record `Default_001`, product **Atlassian Cloud - Marketplace Application**.
3. More than one row with the same `ProductName__c`: that line is skipped (`found = false`). The default product is not used. The text `null` in `SalesforceProductName__c` is treated as no product and also fails the line.

The Opportunity still needs a price book entry for the mapped product in the Opportunity's price book and currency. A missing entry is an error on the pending invoice, because this job passes no log object back to a screen.

Step-by-step field mapping from the invoice line onto the Opportunity Product (dates, prices, SEN, discounts) is in [Quote and invoice import](Quote_And_Invoice_Import.md#commerce-api-invoice-line--opportunity-product).

---

## PPC Invoice Auto Import Settings

Hierarchy custom setting `PPC_InvoiceAutoImportSettings__c`. Setup label: **PPC Invoice Auto Import Settings**.

`PpcInvoiceImporterBatch` and `PpcOpportunityProductMapper` call `getInstance()`. That is the org default, unless a profile or user row overrides it for the running user. The scheduled job therefore follows the org default, or the override for the user who owns the schedule.

| Field | Label | Who reads it | Effect |
| --- | --- | --- | --- |
| `AutomationEnabled__c` | Automation Enabled | `PpcInvoiceImporterBatch` | When unchecked, the Account query is forced to `LIMIT 0`. The scheduled job stays active and imports nothing. Manual quote and invoice import ignore this field. |
| `LastDays__c` | Days back to import invoices from | `PpcInvoiceImporterBatch` | How many days of invoices to consider, from `createdAt`. Default on the field is 5. `PpcInvoiceImporterBatch.run(Integer)` can override this for one execution. |
| `DaysToKeepPendingInvoices__c` | Days to keep pending invoices | `InvoiceToOpportunityBatch` | Age threshold for deleting **Done** rows. |
| `DeletePendingInvoices__c` | Delete pending invoices | `InvoiceToOpportunityBatch` | When checked, **Done** rows older than the keep window are deleted at the end of the batch. |
| `MergeDateRanges__c` | Merge Date Ranges | `PpcOpportunityProductMapper` | After equal lines are merged, lines that share an entitlement number are combined. Start date becomes the earliest, end date the latest. Amounts are summed. User counts are not summed. This also applies to a **manual** Commerce API quote or invoice import when that screen's **Merge Line Items** checkbox is on. |

Equal-line merge (same PPC line id, start date, and end date) is always on for this job. Date-range merge runs only when `MergeDateRanges__c` is checked. Both steps are described in [Quote and invoice import](Quote_And_Invoice_Import.md#merging-line-items).

---

## How to turn it on

1. Link active Invoice Groups to the Account. See [Invoice groups](Invoice_Groups.md).
2. Check **Auto Invoice Import** on the Account.
3. Set **PPC Invoice Auto Import Settings**: automation enabled, days back, and whether date-range merge and pending-invoice cleanup should run.
4. In production this is already scheduled as `Apex Morning Auto Invoice Import`, every day at 08:45 `Europe/Helsinki`. A new org needs the same `System.schedule` (or Setup → Scheduled Jobs) for `PpcInvoiceImporterBatch`.
5. Confirm the subsidiary named credential is healthy. See [PPC credential health](PPC_Credential_Health.md).

Uncheck **Automation Enabled** to stop imports while leaving the schedule in place. Uncheck **Auto Invoice Import** on a single Account to skip that customer.

---

## Batch job monitor

`batchJobMonitor` (label **Batch Job Monitor**) can be placed on an App page, Home page, record page, or tab. It starts the same batch as the schedule, with a day window chosen on the screen, and lists recent runs of the two batch classes.

**Start PPC Invoice Import Batch Job** calls `BatchJobController.startInvoiceImportBatchJob`, which calls `PpcInvoiceImporterBatch.run(daysBack)`. The number input defaults to 5 and is labeled **Number of day(s) back to import invoices from**. That value replaces `LastDays__c` for this execution only. `invoiceWithinTimespan` then keeps invoices whose `createdAt` date is within that many days of today.

The constructor still applies **Automation Enabled**. When that checkbox is off, the Account query is `LIMIT 0` before `daysBack` is applied, so the monitor imports nothing until automation is enabled. It does not bypass the office custom permissions. The running user still needs `Eficode_Office_{CODE}` for every subsidiary that is imported.

`run` returns null and starts nothing when `PpcInvoiceImporterBatch` or `InvoiceToOpportunityBatch` is already Queued, Preparing, Processing, or Holding. The screen still starts polling. The returned job id is not shown as an error.

**Start Monitoring** and **Stop Monitoring** poll `BatchJobController.getApexJobs` every 750 ms. Starting the import also starts that poll. The query is `AsyncApexJob` rows of type `BatchApex` or `BatchApexWorker`, created in the last 2 days, for `PpcInvoiceImporterBatch` and `InvoiceToOpportunityBatch` only. `ProcessOpportunityLinesQueueable` is not in the list. Worker rows are stored on `ChildJobs` and are not rendered. The table shows the parent jobs: class, type, status, created, completed, items processed, total items, and error count.

The screen compares the job id from `run` with `JobId` shortened to 15 characters. Those strings do not match, so a completed run does not stop the poll by itself. **Stop Monitoring** stops it.

---

## Troubleshooting

| What you see | What to check |
| --- | --- |
| No Opportunities created | `AutoInvoiceImport__c` on the Account, `AutomationEnabled__c`, active Invoice Groups, and that the invoice is paid, card, monthly, and inside the day window |
| Invoice skipped | An Opportunity on that Account already has the same `ImportedInvoiceNumber__c` |
| Pending invoice **Error** or **Failed** | `Error__c` and `RetryCount__c`. Row-lock failures retry up to 4 times inside the queueable |
| Lines missing | Product mapping and price book entry for the Opportunity currency. Same rules as manual invoice import |
| Callouts stop mid-account | `getPaidInvoices` stops when fewer than two callouts remain. Extra active Invoice Groups on a large Account may need a later run |
| Duplicate monthly Opportunities | The duplicate check is invoice number per Account. A different invoice number creates a new Opportunity |
