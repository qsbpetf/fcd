# Eficode Salesforce documentation

Documentation for custom features in this Salesforce DX project (`EficodeFreshProd`, API 63.0). Metadata lives under `force-app/main/default`.

These pages describe the implementation in the repository. Source material was the Atlassian integration design notes (2024–2025). Where those notes and the Apex differ, the pages follow the code.

## Atlassian Partner Portal Commerce (PPC)

| Document | What it covers |
| --- | --- |
| [Atlassian PPC overview](Atlassian_PPC_Overview.md) | Subsidiaries, `PPC_TransactionAccount__mdt`, and why one quote or invoice needs many API calls |
| [Invoice groups](Invoice_Groups.md) | Billing profiles synced nightly as `InvoiceGroup__c`, and how sales links them to Accounts |
| [Quote and invoice import](Quote_And_Invoice_Import.md) | Manual JSON and Commerce API import, including how `PortalProductToSalesforceMapping__mdt` and `PpcProductToSalesforceMapping__mdt` match |
| [Monthly invoice auto-import](Monthly_Invoice_Auto_Import.md) | Scheduled card invoices, the PPC product-mapping table, `PPC_InvoiceAutoImportSettings__c`, and the batch job monitor |
| [Currency rate import](Currency_Rates.md) | Daily job that stores marked-up exchange rates for Salesforce and Opportunity Products |
| [Default Opportunity Owner](Default_Opportunity_Owner.md) | Which user owns a monthly renewal Opportunity, via `DefaultOpportunityOwner__c` and a before-save flow |
| [Promotion codes](Promotion_Codes.md) | Marketplace promo codes shown on the quote importer when a fetched quote line matches |
| [PPC credential health](PPC_Credential_Health.md) | Named-credential probes, the Home page dashboard, and Slack when a token fails |
| [Quote and invoice PDF preview](Quote_And_Invoice_PDF_Preview.md) | Visualforce pages that embed the Atlassian quote or invoice PDF |

Atlassian Commerce API reference: [Quotes](https://developer.atlassian.com/platform/commerce/rest/api-group-quotes/#api-v2-quotes-id-get).

## Atlassian Deal Registration

| Document | What it covers |
| --- | --- |
| [Deal and service registration](Atlassian_Deal_Registration.md) | Local drafts, sync and submit, search, detail, and job-status polling |
| [Deal Registration APIs spec](Deal%20Registration%20APIs_Spec.yaml) | OpenAPI spec for the Deal Registration API |
| [Deal Registration Postman collection](Deal%20Registration%20APIs.postman_collection.json) | Postman requests for the same API |

## Other custom features

| Document | What it covers |
| --- | --- |
| [Make.com webhooks](Make_Webhooks.md) | When an Opportunity update or a deleted Opportunity Product is posted to Make.com |
| [MEDDPICC](MEDDPICC.md) | JSON import into Opportunity long text fields, and the viewer that parses them |
| [Opportunity product editor](Opportunity_Product_Editor.md) | Custom add, edit, and delete grid for Opportunity Products |
| [Opportunity splits](Opportunity_Splits.md) | T1, T2, and T3 `OpportunitySplit` rows from `OppSplitEngine`, and which older flows are still active |
| [Tier calculation](Tier_Calculation.md) | `Tier__c` lines, the T2 and T3 formulas, the nightly batch, and the Calculate Tiers flow |
