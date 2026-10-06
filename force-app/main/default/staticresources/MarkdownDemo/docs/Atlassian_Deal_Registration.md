# Atlassian deal and service registration

Sales users create Atlassian Partner Central deal and service registrations from Salesforce, search registrations that already exist in Atlassian, and poll the async job Atlassian returns after submit.

The local record is `AtlassianRegSubmission__c`. Saving the form writes JSON on that record and does not call Atlassian. A separate button creates the draft in Atlassian, and another submits it. The OpenAPI spec and Postman collection in this folder describe the HTTP API. This page describes the Salesforce screens and Apex.

`AtlassianRegSubmission__c` field metadata is not in this repository. The fields below are the ones Apex reads and writes.

---

## Table of Contents

1. [Screens](#screens)
2. [Authentication](#authentication)
3. [Create a local draft](#create-a-local-draft)
4. [Sync, submit, and refresh](#sync-submit-and-refresh)
5. [Search and detail](#search-and-detail)
6. [Job-status polling](#job-status-polling)
7. [API methods](#api-methods)
8. [Local record fields](#local-record-fields)

---

## Screens

| Component | Where it can be placed | What it does |
| --- | --- | --- |
| `atlassianRegistrationCreate` | App page. Label **Deal & Service Registration**. | Asks for Deal Registration or Service Registration, then shows the matching form. |
| `atlassianDealRegDraftForm` | App page, and the `AtlassianRegSubmission__c` record page. | Deal form. Create saves locally. Edit saves locally and, when a registration id exists, PATCHes Atlassian. |
| `atlassianServiceRegDraftForm` | Same targets as the deal form. | Service form. Same save pattern. |
| `atlassianRegEditButton` | Record page action on `AtlassianRegSubmission__c`. | Opens the deal or service form in a modal. |
| `atlassianRegSubmitRefreshButton` | Record page on `AtlassianRegSubmission__c`. | **Create in Atlassian**, **Submit**, and **Refresh** status. |
| `atlassianRegistrationSearch` | Tab, App page, or Home. Label **Atlassian Registration Search**. | Search, then view or edit in a modal. |
| `atlassianRegistrationDetail` | App page, Home, or the submission record page. | Shows one registration, from the API or from the saved JSON. |
| `atlassianPartnerAccounts` | Tab, App page, Home, or a record page. | Lists partner accounts the credential can act on. |

---

## Authentication

Named credential `Atlassian_deal_Reg_API` calls `https://api.atlassian.com`. Authentication is the external credential `Atlassian_Deal_Reg_EC` (OAuth, named principal **PartnerCentral**, identity provider `Atlassian_Deal_Reg_IDP`).

Scopes on that external credential:

`create:deal-registration:partnercentral`, `update:deal-registration:partnercentral`, `submit:deal-registration:partnercentral`, `read:deal-registration:partnercentral`, `create:service-registration:partnercentral`, `update:service-registration:partnercentral`, `submit:service-registration:partnercentral`, `read:service-registration:partnercentral`, `search:registration:partnercentral`, `read:partner-accounts:partnercentral`, `read:jobs:partnercentral`, `offline_access`.

`AtlassianDealRegApiClient` sends `Accept: application/json` and a 120 second timeout. Every call except partner-account list also sends `X-Partner-Account-Id` with the partner id from the partner-account list (`partnerId`, not the Salesforce Account id).

Partner accounts are cached for 15 minutes on `ApiResponseCache__c` with `CacheKey__c` = `PartnerAccounts`. A refresh button passes `forceRefresh = true`, skips the cache read, and upserts the cache when Atlassian returns 200.

---

## Create a local draft

On the create screen the user picks **Deal Registration** or **Service Registration**, picks a partner account, fills the form, and clicks **Create**.

`createLocalDealDraft` or `createLocalServiceDraft` inserts `AtlassianRegSubmission__c` and does not call Atlassian. `dealName` and the partner account are required. The payload must be JSON. The record name is the deal name, cut to 80 characters. `Deal_Name__c` keeps up to 255 characters. `Program_Type__c` is `DEAL_REGISTRATION` or `SERVICE_REGISTRATION`. `Registration_Id__c` stays blank. The screen then opens the new record.

Both forms put `programType` on the JSON. Other keys are included only when the user filled them. Booleans that the form always sends are listed as always.

Deal payload keys: `parentRegistrationId`, `dealName`, `programType`, `partnerSubmittedOpportunityNumber`, `products`, `customerHasCloudSite`, `cloudSite`, `notes`, `termsAccepted` (always), `sowConfirmed` (always), `termsConfirmed` (always), `detailedDescription`, `platform` (`CLOUD`, `DATA_CENTER`, `BOTH`), `estimatedRevenue` (number), `customerContactEmailId`, `customerDomain`, `partnerSalesRepresentativeEmailId`, `estimatedOpportunityCloseDate`, `comments`, `dealRegDcExceptionReason`, `budgetAllocated` (`YES`, `NO`, `UNKNOWN`), `customerKeyDecisionMakersEngagedInProcess` (always), `crucialEvent`, `rfpRelated` (always), `rfpRelatedTo`, `salesType`, `senOrEntitlementNumber`, `additionalInfo`, `eccListedAboveIsKeyDecisionMaker` (always), and `eccKeyDecisionMaker` (first name, last name, email, job title).

Sales types: `NEW`, `UPGRADE`, `RENEWAL`, `NEW_PRODUCT`, `EXPANSION_UPGRADE`, `PLATFORM_CHANGE_WITH_EXPANSION_UPGRADE`, `PLATFORM_CHANGE_WITHOUT_EXPANSION_UPGRADE`.

RFP related to: `ATLASSIAN_SPECIFIED_PRODUCT_PROPOSAL`, `GENERAL_SOLUTION_PROPOSAL`, `GOVERNMENT_TENDER`.

Service payloads add `solution`, `regions` (`APAC`, `AMER`, `EMEA`), `departments` (comma-separated text, sent as a list), `serviceType`, `serviceEngagementStage` (`DELIVERY_NOT_STARTED`, `DELIVERY_IN_PROGRESS`, `DELIVERY_COMPLETED`), `serviceStartDate`, `serviceEndDate`, `deliveryConsultant`, `deliveryConsultantEmail`, `userCount`, `entityType` (`OPPORTUNITY_NUMBER`, `SEN`, `ORDER_NUMBER`, `INVOICE_ID`, `ENTITLEMENT_NUMBER`, `DEAL_REGISTRATION_ID`), and `entityIds` (comma-separated text, sent as a list).

Service types: `CLOUD_MIGRATION_AND_EXPANSION`, `CONFIGURATION_AND_ADMINISTRATION`, `PARTNER_SOLUTION_CONSULTING_ARCHITECTURE`, `PRODUCT_IMPLEMENTATION`, `PROJECT_SUPPORT_AND_MAINTENANCE_SUPPORT_SERVICES`, `TRAINING`, `OTHER`.

Solutions: `ENTERPRISE_STRATEGY_AND_PLANNING`, `CLOUD_MIGRATION`, `SERVICE_MANAGEMENT`, `SOFTWARE_DEVELOPMENT`, `TEAMWORK_FOUNDATIONS`, `OTHER`.

Product codes are the constants at the top of `atlassianDealRegDraftForm.js` and `atlassianServiceRegDraftForm.js`. The service list is shorter than the deal list.

The form is read-only when the status it has loaded is `APPROVED`, `EXPIRED`, `CLOSED_WON`, `CLOSED_LOST`, `CLOSED`, or `REJECTED`. **Submit** on the form itself is shown only in edit mode when status is `DRAFT`. **Poll** on the form is shown only when status is `IN_PROGRESS`. Those form buttons need a Salesforce record id. The record-page buttons below are the ones used after the local create.

---

## Sync, submit, and refresh

`atlassianRegSubmitRefreshButton` on the submission record:

| Button | When it shows | What it calls |
| --- | --- | --- |
| Create in Atlassian | `Registration_Id__c` is blank | `AtlassianDealRegDraftController.syncDraftToAtlassian` |
| Submit | A registration id exists and status is `DRAFT` | `submitDealDraft` or, when `Program_Type__c` is `SERVICE_REGISTRATION`, `AtlassianServiceRegDraftController.submitServiceDraft` |
| Refresh | Status is `IN_PROGRESS`, `COMPLETED`, `FAILED`, or `VALIDATION_ERROR` | `pollJobStatus` |

Sync refuses a record that already has a registration id, an empty payload, or a blank partner account id. It POSTs the stored JSON. Atlassian must return **201**. The record then stores `Registration_Id__c`, `Status__c`, and the name `Draft ` plus the registration id.

Submit refuses a record with no registration id. It POSTs to the submit path. Atlassian must return **202**. The record stores `Job_Id__c`, `Status__c`, `Last_Polled__c`, and `Error__c` when the body contains an error.

Refresh calls job status and writes `Status__c`, `Last_Polled__c`, and `Error__c`. It requires `Job_Id__c`.

`atlassianRegEditButton` opens the form for the program type on the record. The button stays enabled while there is no registration id, so a local-only draft can be edited. After Atlassian has an id, the button is enabled only while status is `DRAFT`. Saving an edit calls `saveDraftPayload`. That writes the JSON locally and, when `Registration_Id__c` is set, PATCHes the deal or service. Atlassian must return **204**.

`createDealDraft`, `updateDealDraft`, `createServiceDraft`, and `updateServiceDraft` create or update in Atlassian in one step and store the result. None of the Lightning components call them. The screens always save locally first.

---

## Search and detail

Search requires a partner account. Filters:

| Filter | Sent as |
| --- | --- |
| Status | One or more of `DRAFT`, `USE_CHILD_REGISTRATIONS`, `SUBMITTED`, `APPROVED`, `REJECTED`, `CLOSED_WON`, `CLOSED_LOST`, `CLOSED`, `RETURNED`, `FIELD_APPROVED`, `ON_HOLD`, `EXPIRED`, `PENDING`, `UNDER_REVIEW`, joined with commas |
| Program type | Blank (all), `DEAL_REGISTRATION`, or `SERVICE_REGISTRATION` |
| Registration id, parent registration id | Optional |
| Registration type | `PARENT` or `CHILD` |
| Created after / before | Date only. Apex appends `T00:00:00Z` or `T23:59:59Z`. |
| Page size | Default 10. Values outside 1–100 are sent as 10. The query parameter name is `limit`. |
| Sort | Default `CREATED_AT` `DESC`. Other sort fields: `LAST_MODIFIED_AT`, `REGISTRATION_ID`, `STATUS`, `PROGRAM_TYPE`. Order `ASC` or `DESC`. |

Search must return **200**. The response `X-Trace-Id` is kept on the result as `traceId`. Next and previous use `pagination.nextPageToken`. The component also filters the returned rows by program type in the browser.

The table shows id, deal name, program type, status, customer domain, `partnerSubmittedOpportunityNumber`, estimated revenue formatted as EUR, expiration date, and created time. **View** opens `atlassianRegistrationDetail` in a modal. **Edit** in that modal loads the draft form. If Salesforce has no submission for that registration id and partner account, Save calls `updateDealDraftByRegistrationId` or `updateServiceDraftByRegistrationId`. That PATCHes Atlassian and does not insert `AtlassianRegSubmission__c`.

On a submission record, the detail component loads `getSubmissionRecord`. When both `Registration_Id__c` and `Partner_Account_Id__c` are set, it GETs the live registration. Otherwise it renders `Draft_Payload_JSON__c` and shows id `(not synced to Atlassian yet)` and status `Local draft`. A blank payload shows "No draft data saved on this record yet."

Off a record, the detail component reads `c__registrationId`, `c__partnerAccountId`, and `c__programType` from the URL. A blank program type is sent as `DEAL_REGISTRATION`. `getRegistration` calls the deals path unless the program type normalizes to `SERVICE_REGISTRATION` (spaces become underscores, then uppercase). Get must return **200**.

The detail layout groups core fields, customer, partner, revenue, products and platform, terms, description, and deal context. Service-only keys (`solution`, `regions`, `departments`, `serviceType`, dates, delivery consultant, `userCount`, `entityType`, `entityIds`) and any other non-empty key are shown as additional fields.

`requestDealExtension` exists on `AtlassianDealRegApiClient` (`POST /partner/registrations/v1/deals/{id}/extensions`). No Lightning component calls it.

---

## Job-status polling

Submit is asynchronous. The submit response is a job, not the final registration status.

Manual refresh is `pollJobStatus` on the record, described above.

`AtlassianDealRegJobStatusPollBatch` selects submissions where `Job_Id__c` and `Partner_Account_Id__c` are set and `Status__c` is exactly `IN_PROGRESS`. Scope size is 10. For each row it calls job status:

- On success it writes `Status__c`, `Last_Polled__c`, and `Error__c` when the body has an error.
- When the new status is `COMPLETED` or `SUCCESS` and the old `Error__c` was filled, it clears `Error__c`.
- When the call throws `AtlassianDealRegApiException`, it writes `Error__c` and `Last_Polled__c` and leaves `Status__c` as `IN_PROGRESS`, so the next run tries again.

`AtlassianDealRegJobStatusPollScheduler` starts that batch. The class comment gives the schedule `Atlassian Deal Reg Job Status Poll` with cron `0 0 * * * ?` (hourly, at minute 0). This page does not confirm that job is scheduled in production. The batch does not reschedule itself.

Job status must return **200**. The wrapper fields are `jobId`, `status`, `createdAt`, `lastModifiedAt`, `registrationId`, and `error`.

---

## API methods

`AtlassianDealRegApiClient` paths, all under `callout:Atlassian_deal_Reg_API`:

| Method | Path | Expected status |
| --- | --- | --- |
| GET partner accounts | `/partner/partner-accounts/v1/list` | 200 to refresh the cache |
| POST deal draft | `/partner/registrations/v1/deals` | 201 |
| POST service draft | `/partner/registrations/v1/services` | 201 |
| GET or PATCH deal | `/partner/registrations/v1/deals/{id}` | GET 200, PATCH 204 |
| GET or PATCH service | `/partner/registrations/v1/services/{id}` | GET 200, PATCH 204 |
| POST submit deal | `/partner/registrations/v1/deals/{id}/submit` | 202 |
| POST submit service | `/partner/registrations/v1/services/{id}/submit` | 202 |
| GET search | `/partner/registrations/v1/search` | 200 |
| GET job | `/partner/jobs/v1/{jobId}/status` | 200 |

`AtlassianDealRegApiRegistrations` turns a non-matching status into `AtlassianDealRegApiException`. The message includes Atlassian's `statusCode`, `message`, and `errors` when the body is that shape.

---

## Local record fields

Written by the draft controllers and the poll batch:

| Field | Role |
| --- | --- |
| `Name` | Deal name, max 80, until sync renames it to `Draft ` plus the registration id |
| `Deal_Name__c` | Deal name, max 255 |
| `Draft_Payload_JSON__c` | Full form JSON |
| `Program_Type__c` | `DEAL_REGISTRATION` or `SERVICE_REGISTRATION` |
| `Partner_Account_Id__c` | Atlassian `partnerId` |
| `Registration_Id__c` | Atlassian id, for example `D-…` or `CD-…`. Blank until sync. |
| `Status__c` | Status returned by create, submit, or job status |
| `Job_Id__c` | Set on submit. Required for refresh and for the poll batch. |
| `Last_Polled__c` | Set on submit and on each poll |
| `Error__c` | Job error text, or the exception message from a failed poll |

Queries that load a submission for edit, submit, or poll use `WITH SECURITY_ENFORCED`.
