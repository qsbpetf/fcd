# Invoice Groups (Atlassian billing profiles)

Invoice Groups are how Salesforce represents Atlassian PPC billing profiles. They are the link between an Account and the quotes and invoices that can be retrieved for that customer.

---

## Table of Contents

1. [Why Invoice Groups exist](#why-invoice-groups-exist)
2. [What is synchronized](#what-is-synchronized)
3. [Nightly sync](#nightly-sync)
4. [Linking Invoice Groups to Accounts](#linking-invoice-groups-to-accounts)
5. [Fields](#fields)
6. [List views](#list-views)

---

## Why Invoice Groups exist

PPC has billing profiles, not customers. One Eficode customer can have several billing profiles. A profile that should no longer be used is set inactive in PPC.

Every quote, order, invoice, and billing profile belongs to one transaction account. In Salesforce that transaction account is the Account subsidiary (`CV_Subsidiary__c`). See [Atlassian PPC overview](Atlassian_PPC_Overview.md).

`InvoiceGroup__c` is a child of Account. An Account can have zero, one, or many Invoice Groups. The sync creates and updates the Invoice Group rows. It does not set `Account__c`. Sales sets that lookup so later invoice and quote calls know which billing profile belongs to which customer.

---

## What is synchronized

`PortalInvoiceGroupSyncQueueable` walks every office from `PortalCommerceApiAccessMgmt.getAllOffices()`, pages billing profiles 50 at a time, and upserts on `AtlassianInvoiceGroupId__c`.

| Invoice Group field | Source |
| --- | --- |
| `Name` | Billing profile name, truncated to 79 characters |
| `AtlassianInvoiceGroupId__c` | Billing profile id (external id for the upsert) |
| `ShipToPartyName__c` | Ship-to party name |
| `ShipToPartyVatTaxId__c` | Ship-to party VAT / tax id |
| `CV_Subsidiary__c` | Office code for the transaction account being synced |
| `Active__c` | Active flag from PPC |
| `Slug__c` | Slug |
| `CurrencyIsoCode` | `isoCurrency` from the billing profile |
| `Version__c` | Version |
| `CreatedAt__c` | Created timestamp from PPC, stored as a date |
| `LastSynchronized__c` | Time of this Salesforce sync |
| `Account__c` | Left for users. The upsert does not set it, so an existing link is kept |

Inactive profiles are still imported. `Active__c` is updated from PPC. Invoice lists and the monthly importer only use groups where `Active__c` is true.

---

## Nightly sync

`PortalInvoiceGroupSyncSchedulable` enqueues `PortalInvoiceGroupSyncQueueable`.

In Eficode production the job is scheduled and waiting:

| | |
| --- | --- |
| Scheduled job name | `Apex InvoiceGroups Atlassian PPC` |
| Apex class | `PortalInvoiceGroupSyncSchedulable` |
| Cron | `0 0 4 ? * 1,2,3,4,5,6,7` |
| When | Every day at 04:00, org timezone `Europe/Helsinki` |

The queueable chains itself: next page while `nextId` is present, then the next office. An error on one office is logged and the job moves on to the next office.

---

## Linking Invoice Groups to Accounts

1. Open the Invoice Group list view that matches the subsidiary (or **All**).
2. Sort by ship-to name, VAT id, or slug to find the customer.
3. Select one or more rows and set **Account** to the Salesforce Account. Several Invoice Groups can be linked to the same Account in one edit.

On the Account, the related Invoice Groups are the billing profiles that the **Atlassian PPC Invoices** tab and the monthly importer will query.

A new billing profile appears after the next sync with `Account__c` empty until someone links it. A profile set inactive in PPC stays on the Account with `Active__c` unchecked and drops out of invoice retrieval.

---

## Fields

Object: `InvoiceGroup__c`.

Users need the ship-to name, VAT id, slug, subsidiary, currency, active flag, and created date to decide which Account to link. `LastSynchronized__c` shows whether the row was refreshed on the last run.

---

## List views

List views on `InvoiceGroup__c` include:

- `All`
- One “all” view per subsidiary: `Sweden_All`, `Finland_All`, `Norway_All`, `Denmark_All`, `UK_All`, `US_All`, `Netherlands_All`, `Germany_All`, `Switzerland_All`, `Jodocus_All`
- “To be done” views for groups that still need an Account, for the same subsidiaries (plus `TO_BE_DONE_Anglosphere`)

Filter a view on `CV_Subsidiary__c` when a country-specific queue is easier than **All**.
