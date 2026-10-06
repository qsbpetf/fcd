# Make.com webhooks

Salesforce posts a small JSON body to Make.com when an Opportunity is updated while it sits in a configured stage, and when an Opportunity Product is deleted from such an Opportunity. Make.com is the Agile Day integration. The named credential is `MakeDotCom` (`https://hook.eu1.make.celonis.com`, no authentication header). The webhook paths are constants on the queueable classes.

The class comment says the call happens when the stage changes. The code does not compare the old stage to the new stage. Any later update of an Opportunity that already meets the rules sends the webhook again. `MakeOpportunityWebhookQueueableTest.testWebhookWhenOtherFieldsChangeInConfiguredStage` covers that case.

---

## Table of Contents

1. [When an Opportunity update sends a webhook](#when-an-opportunity-update-sends-a-webhook)
2. [When a deleted product sends a webhook](#when-a-deleted-product-sends-a-webhook)
3. [What is posted](#what-is-posted)
4. [Configured stages](#configured-stages)
5. [Kill switch](#kill-switch)
6. [What does not send a webhook](#what-does-not-send-a-webhook)

---

## When an Opportunity update sends a webhook

`customOppTrigger` calls `MakeWebhookOpportunityHandler.handleAfterUpdate` on **after update** only. Insert does not call it. The handler reads the Opportunity again (stage, revenue types, closed flag, close date, account name) and ignores the old field values except to confirm `oldMap` is present.

A webhook is enqueued only when every rule below is true:

| Rule | Code |
| --- | --- |
| Stage is one of the active production rows in `MakeWebhookOpportunityStageConfig__mdt` | `StageName` is an exact match. The match is case-sensitive. |
| Revenue Types is filled and is not exactly `Licenses` | `Revenue_Types_Declarative__c != null` and `equalsIgnoreCase('Licenses')` is false. The field is a text area filled by Rollup Helper. `Services` sends a webhook. The exact text `Licenses` does not. A value that merely contains the word, such as `Licenses, Services`, still sends a webhook. |
| The Account is set and `Account.Name` is not blank | |
| The Opportunity is open, or it was closed recently | `IsClosed` is false, or `CloseDate` is today or within the previous 15 days (`CloseDate >= Date.today().addDays(-15)`). A closed Opportunity with a blank close date does not send a webhook. Closed 16 or more days ago does not. |
| At least one Opportunity Product has `UnitPrice` not null | `UnitPrice` of 0 counts. A line with a null unit price does not. |
| The kill switch is not off | See [Kill switch](#kill-switch). |

All matching Opportunity ids from the trigger are passed to one `MakeOpportunityWebhookQueueable`. That job sends one HTTP POST per id. A second update of the same Opportunity in the **same transaction** does not enqueue again. The handler keeps a static set of ids it has already accepted. A later transaction sends again.

Creating the Opportunity already in a configured stage does not send a webhook. Adding the first priced product later does not either, because the product trigger does not call the Opportunity handler. The next update of the Opportunity, while a priced line exists, does.

---

## When a deleted product sends a webhook

`MakeWebhookOpportunityLineItemTrigger` runs **after delete** on `OpportunityLineItem` and calls `handleOLIAfterDelete`.

Each deleted row is posted when all of these are true:

- The deleted row has `UnitPrice` not null. A null unit price is skipped. The handler reads `UnitPrice` from `Trigger.old`, not from a new query.
- The parent Opportunity passes the same stage, revenue-type, account, and close-date rules as an Opportunity update.
- The kill switch is not off.

The delete path does not require any priced line to remain on the Opportunity. Deleting the last priced line still posts, as long as that line itself had a unit price and the parent still qualifies.

One `MakeOLIWebhookQueueable` is enqueued for the deleted ids. It sends one POST per id. The same static-set rule applies inside one transaction.

Deleting a product does not also send the Opportunity webhook.

---

## What is posted

Both jobs use `callout:MakeDotCom` plus a path constant, method POST, header `Content-Type: application/json`. The HTTP status is not checked. A failed call is written with `System.debug` and is not retried. The Opportunity or product change still commits.

| Event | Class | Body |
| --- | --- | --- |
| Opportunity update | `MakeOpportunityWebhookQueueable` | `{ "OpportunityId": "<id>" }` |
| Product delete | `MakeOLIWebhookQueueable` | `{ "OpportunityLineItemId": "<id>" }` |

The queueable loops every id in one execution. A single trigger that deletes more than 100 qualifying lines can hit the callout governor limit, because the job does not chain itself.

---

## Configured stages

Custom metadata type **Make Webhook Opportunity Stage Config** (`MakeWebhookOpportunityStageConfig__mdt`).

| Field | Role |
| --- | --- |
| `StageName__c` | Exact `Opportunity.StageName` value |
| `IsActive__c` | Inactive rows are ignored |
| `IsTestRecord__c` | Production loads rows where this is false or blank. Apex tests load only rows where it is true. |
| `Description__c` | Comment. The description text says the webhook fires when the Opportunity moves to the stage. The handler fires on any qualifying update, including updates that leave the stage unchanged. |

Production rows, all active, `IsTestRecord__c` false:

| Stage |
| --- |
| Evaluate |
| Develop Solution |
| Justify |
| Closing |
| Order |
| Closed won - awaiting approval |
| Closed Lost |
| Cancelled After Invoice |
| Duplicate - Dead Quote |
| Duplicate - Error in Opp |
| Duplicate - Multiple Options |

`Test_ClosedWonAwaitingApproval` uses stage `Closed won - awaiting approval` with `IsTestRecord__c` true. Tests use it. Production ignores it.

An empty active set means no webhooks. Adding a stage is a metadata row whose `StageName__c` matches the Opportunity stage picklist value exactly.

---

## Kill switch

`MakeWebhookSettings__c`, field **Enable Opportunity Webhook** (`EnableOpportunityWebhook__c`). The field default is checked. Help text: uncheck to temporarily disable all Make.com webhooks. Apex reads it with `getInstance()`, which is the hierarchy custom-setting call. The object file in this repo does not declare `customSettingsType`.

`isWebhookEnabled` uses `getInstance()`:

- No setting row: webhooks stay on.
- Checkbox false: both the Opportunity job and the product-delete job are skipped.
- Checkbox true, or null on a returned row: webhooks stay on.

The same checkbox covers both webhooks. There is no separate switch for product deletes.

---

## What does not send a webhook

- Opportunity insert, including an insert that is already in a configured stage
- An update while Revenue Types is blank, or exactly `Licenses`
- An update with no Account, or a blank Account name
- An update of a closed Opportunity whose close date is older than 15 days
- An Opportunity update when every product has a null unit price
- Product insert or product update
- Deleting a product whose unit price is null
- A second qualifying change to the same record inside one transaction
