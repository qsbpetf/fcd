# Atlassian PPC Credential Health

This document describes the Atlassian Partner Portal Commerce (PPC) named-credential health check: why it exists, how it is designed, which metadata it uses, and how to operate it.

Related docs: [Atlassian PPC overview](Atlassian_PPC_Overview.md), [quote and invoice import](Quote_And_Invoice_Import.md), [invoice groups](Invoice_Groups.md), [monthly invoice auto-import](Monthly_Invoice_Auto_Import.md).

---

## Table of Contents

1. [What this solves](#what-this-solves)
2. [How Atlassian PPC access works today](#how-atlassian-ppc-access-works-today)
3. [Overall architecture](#overall-architecture)
4. [Design](#design)
5. [Configuration](#configuration)
6. [How to see connection status](#how-to-see-connection-status)
7. [Scheduled jobs](#scheduled-jobs)
8. [User guide](#user-guide)
9. [Slack notifications from a Flow](#slack-notifications-from-a-flow)
10. [Metadata created or changed](#metadata-created-or-changed)
11. [Deploy](#deploy)
12. [Troubleshooting](#troubleshooting)

---

## What this solves

Each Eficode subsidiary talks to Atlassian PPC through its own Salesforce **named credential**. The username is the Atlassian **transaction account UUID**. The password is the API token.

If a token expires, a named credential is misconfigured, or Atlassian returns errors, invoice and quote integrations fail per subsidiary. Before this feature there was no dedicated health check: failures only showed up when someone imported an invoice or a scheduled sync job failed.

This solution:

- Probes every PPC named credential on a schedule (every 20 minutes)
- Stores the latest HTTP status per subsidiary in a custom object
- Shows the status on a Home page dashboard
- Lets you click **Probe now** without waiting for the schedule
- Gives a Flow a stable `Status__c` field to send Slack when health changes

---

## How Atlassian PPC access works today

Callouts go through `PortalCommerceApiClient` to `https://api.atlassian.com/commerce/api/...`.

Authentication headers (from the named credential merge fields):

- `Authorization: Bearer {!$Credential.Password}` (API token)
- `X-transaction-account: {!$Credential.Username}` (transaction account UUID)

Each subsidiary has a named credential `Eficode_Office_{CODE}` and a matching `PPC_TransactionAccount__mdt` record.

| Named credential | CMDT developer name | Account subsidiary value (`CV_Subsidiary__c`) |
|---|---|---|
| `Eficode_Office_FI` | `FI` | `FI` |
| `Eficode_Office_SE` | `SE` | `SE` |
| `Eficode_Office_NO` | `NO` | `NO` |
| `Eficode_Office_DK` | `DK` | `DK` |
| `Eficode_Office_DE` | `DE` | `DE` (Ex-Germany; inactive on Account) |
| `Eficode_Office_NL` | `NL` | `NL` |
| `Eficode_Office_CH` | `CH` | `CH` |
| `Eficode_Office_UK` | `UK` | `UK` |
| `Eficode_Office_US` | `US` | `US` |
| `Eficode_Office_JODOCUS` | `JODOCUS` | `Jodocus GmbH` |

UK and US share the same transaction account UUID but are still two named credentials, so both are probed.

The health check does **not** use the running user’s office custom permissions. A scheduled job must be able to probe every credential, not only offices the current user can import for.

---

## Overall architecture

```
PPC_TransactionAccount__mdt
        │  (which offices / named credentials exist)
        ▼
Schedulable (every 20 min: three hourly jobs at :00, :20, :40)
        │
        ▼
Queueable + callouts
        │  GET /commerce/api/v2/invoice-groups?page-size=1
        │  per named credential, 10 second timeout
        ▼
PpcCredentialStatus__c  (one row per named credential)
        │
        ├── Home page LWC  (read status; optional Probe now)
        └── Record-triggered Flow on Status__c  (Slack — built separately)
```

The dashboard never calls Atlassian. The scheduled (or manual) probe is the source of truth. The custom object is what the UI and a Slack Flow both consume.

---

## Design

### Probe

`PortalCommerceApiClient.probeOffice(office)` issues:

```
GET callout:Eficode_Office_{CODE}/commerce/api/v2/invoice-groups?page-size=1
```

with the transaction-account header.

Why this endpoint:

- It is a light GET (`page-size=1`)
- It uses **both** the bearer token and `X-transaction-account`
- Product catalog calls skip the transaction-account header, so a bad UUID could still look healthy

The probe:

- Uses a **10 second** timeout (normal PPC callouts use 120 seconds)
- Does **not** check the user’s office custom permission
- Treats HTTP 4xx/5xx as results, not thrown exceptions
- Returns HTTP 0 and **Other Error** if the named credential is missing, the call times out, or another exception occurs

Salesforce limits cumulative callout time to 120 seconds per transaction. Ten offices × 10 seconds stays under that limit, so all offices are probed in **one Queueable**.

### Status mapping

| HTTP result | `Status__c` API value | Label | Typical meaning |
|---|---|---|---|
| 2xx | `Healthy` | Healthy | Token and transaction account work |
| 4xx | `Unhealthy` | Unhealthy | Client/auth problem (400, 401, 403, …) |
| 5xx, timeout, missing named credential, other exception | `Other_Error` | Other Error | Atlassian down, network, or config missing |
| Never probed | `Unknown` | Unknown | Seed / before first run |

`HttpStatusCode__c` is `0` when there was no HTTP response.

On success, `ConsecutiveFailures__c` resets to 0 and `LastSuccess__c` is set. On failure, consecutive failures increment and `LastFailure__c` is set. `LastChecked__c` is updated on **every** run, including when status does not change.

That split is deliberate: a Slack Flow should trigger on **`Status__c` IsChanged**, not on `LastChecked__c`. Otherwise Slack would fire every 20 minutes per office.

### Which offices are probed

The job loops `PPC_TransactionAccount__mdt.getAll()`, not a hardcoded list. Adding a new subsidiary is: named credential + CMDT record + (if needed) picklist value on `PpcCredentialStatus__c.CV_Subsidiary__c`.

Subsidiary on the status record is the Account picklist value from `SubsidiaryApiName__c` (for example `Jodocus GmbH`), not the named-credential suffix `JODOCUS`. The unique upsert key is `NamedCredentialName__c`.

### Overlap protection

If a previous `PpcCredentialHealthQueueable` is still `Queued` / `Preparing` / `Processing` / `Holding`, the next enqueue is skipped. **Probe now** then shows *A PPC credential health check is already running.*

### Dashboard refresh

The LWC does not receive a push when Apex writes new rows.

- While the Home page is open, it re-queries Apex every **60 seconds**
- **Probe now** polls every **3 seconds** for up to **45 seconds** until `LastChecked` is newer than the click
- A card is **stale** if `LastChecked__c` is blank or older than **45 minutes** (one missed 20-minute slot plus buffer)

---

## Configuration

There are two configuration layers. They do different jobs.

### Custom metadata: `PPC_TransactionAccount__mdt`

**What it controls:** which subsidiaries exist and how they map to named credentials.

This type already existed for invoice/quote routing. The health check **reuses** it. It is not a new CMDT.

| Field | Role |
|---|---|
| **Developer name** | Office code used in `Eficode_Office_{DeveloperName}` |
| **Master label** | Transaction account UUID (same value as named credential username) |
| **Subsidiary API Name** (`SubsidiaryApiName__c`) | Account `CV_Subsidiary__c` value (`FI`, `Jodocus GmbH`, …) |

How to manage:

1. Setup → **Custom Metadata Types**
2. **PPC Transaction Account** → **Manage Records**

To add a subsidiary the health check should probe:

1. Create named credential `Eficode_Office_{CODE}` (token in password, UUID in username, header merge fields enabled)
2. Create a `PPC_TransactionAccount__mdt` record with developer name `{CODE}` and subsidiary API name matching Account
3. If the subsidiary value is new, add it to `PpcCredentialStatus__c.CV_Subsidiary__c`
4. The next probe (scheduled or **Probe now**) upserts a status row

Do not delete a CMDT row if you still need invoice import for that office. The health job will stop probing it only after the CMDT record is gone.

### Hierarchy custom setting: `PPC_HealthCheckSettings__c`

**What it controls:** whether the **scheduled** job is allowed to probe.

Label in Setup: **PPC Health Check Settings**.

| Field | Default | Role |
|---|---|---|
| **Enabled** (`Enabled__c`) | `true` (on the field definition) | Kill switch for scheduled probes |

Behaviour:

- If **no org-default record has been saved**, scheduled runs are treated as **enabled**
- If an org-default record exists and **Enabled** is unchecked, scheduled `execute()` returns without enqueueing a probe
- **Probe now** on the dashboard **still runs** when the kill switch is off

How to pause scheduled probes without unscheduling the Apex jobs:

1. Setup → **Custom Settings**
2. **PPC Health Check Settings** → **Manage**
3. **New** at the organization level (or edit the org default)
4. Uncheck **Enabled** → **Save**

Turn it back on by checking **Enabled** again. The three scheduled jobs can stay in **Scheduled Jobs**.

This is a **hierarchy custom setting**, not custom metadata. Change it in the org without a metadata deploy.

---

## How to see connection status

### Home page dashboard (primary)

Lightning component **PPC Credential Health** (`ppcCredentialHealth`).

Each named credential is a card with:

- Subsidiary label (Finland, Germany, …)
- Status badge (Healthy / Unhealthy / Other Error / Unknown)
- Named credential developer name
- HTTP code, last checked (relative time), response time, consecutive failures
- Error snippet when the last probe was not healthy
- Stale warning when last check is older than 45 minutes

**Probe now** starts the same Queueable as the schedule.

To add it:

1. Gear → **Edit Page** on a Home page (or Lightning App Builder → Home)
2. Drag **PPC Credential Health** onto the canvas
3. **Save** and **Activate** if needed

The component is exposed for Home and App pages, not record pages. Users need the **Atlassian PPC Access** permission set (or equivalent) to read `PpcCredentialStatus__c` and run the Apex controller.

### PPC Credential Status tab and list views

Object tab **PPC Credential Statuses** (`PpcCredentialStatus__c`). After deploy, pin the tab or open it from the App Launcher.

Two list views ship with the object:

| List view | API name | What it shows |
|---|---|---|
| **All** | `All` | Every credential. Scope: everything the user can see. |
| **Unhealthy** | `Unhealthy` | Rows where **Status** is **Unhealthy** *or* **Other Error**. |

**All** columns: Name, Eficode Subsidiary, Named Credential Name, Status, HTTP Status Code, Last Checked, Last Success, Last Failure, Consecutive Failures, Response Time (ms).

**Unhealthy** columns: the same operational fields, plus Last Failure instead of Last Success (no Response Time column). Filter logic is `Status = Unhealthy OR Status = Other Error`.

How to use them:

1. App Launcher → **PPC Credential Statuses**.
2. Use the list-view picker (top left) to switch **All** / **Unhealthy**.
3. Sort by **Status** or **Last Checked**. Open a row for the error body and field history.
4. Optionally click **New** on a list view (clone) to filter one subsidiary, e.g. `Eficode Subsidiary equals FI`.

**Atlassian PPC Access** has the tab **Visible**. Users without that permission set will not see the tab unless their profile already includes it.

Field history is on for **Status**. Open a record → related **Status History** (or field history list) to see Healthy ↔ Unhealthy flaps without Slack.

### Record fields

| Field | API name | Notes |
|---|---|---|
| Named Credential Name | `NamedCredentialName__c` | Unique external id, e.g. `Eficode_Office_FI` |
| Eficode Subsidiary | `CV_Subsidiary__c` | Restricted picklist aligned with Account |
| Transaction Account Id | `TransactionAccountId__c` | UUID |
| Status | `Status__c` | Flow trigger field |
| HTTP Status Code | `HttpStatusCode__c` | `0` = no HTTP response |
| Last Checked | `LastChecked__c` | Every run |
| Last Success | `LastSuccess__c` | Last 2xx |
| Last Failure | `LastFailure__c` | Last non-2xx / exception |
| Error Message | `ErrorMessage__c` | Truncated body or exception (max 4000 characters stored from the probe) |
| Consecutive Failures | `ConsecutiveFailures__c` | Dashboard / optional Flow filter; Slack design does not require it |
| Response Time (ms) | `ResponseTimeMs__c` | Probe duration |

---

## Scheduled jobs

Salesforce does **not** allow comma lists in the minutes field of a cron expression (`0 0,20,40 * * * ?` throws *Seconds and minutes must be specified as integers*). Every 20 minutes is therefore **three** hourly jobs:

| Job name | Cron | When it runs |
|---|---|---|
| `PPC Credential Health Check 0` | `0 0 * * * ?` | Minute 0 of every hour |
| `PPC Credential Health Check 1` | `0 20 * * * ?` | Minute 20 of every hour |
| `PPC Credential Health Check 2` | `0 40 * * * ?` | Minute 40 of every hour |

All three are scheduled in Eficode production, state WAITING, class `PpcCredentialHealthSchedulable`. The org timezone is `Europe/Helsinki`.

Each job’s `execute()` enqueues **one** `PpcCredentialHealthQueueable` that probes all offices. Overlap protection stops a second Queueable if the previous run is still going.

### Start

Anonymous Apex (or Developer Console → Execute):

```apex
PpcCredentialHealthSchedulable.start();
```

Repo helper: `scripts/start_ppc_health_schedule.apex`.

`start()` aborts any existing jobs with those three names, then registers them again. Safe to run more than once.

### Stop

```apex
PpcCredentialHealthSchedulable.stop();
```

That aborts the three `CronTrigger` records. After `stop()`, nothing probes until you `start()` again or use **Probe now**.

You can also abort them in Setup → **Scheduled Jobs** (search for `PPC Credential Health Check`). Prefer `stop()` so all three are removed together.

### Pause without unscheduling

Uncheck **PPC Health Check Settings → Enabled** (org default). The three jobs stay scheduled but skip the probe. **Probe now** still works.

### Confirm they are running

1. Setup → **Scheduled Jobs** — three jobs named `PPC Credential Health Check 0/1/2`, state WAITING
2. Setup → **Apex Jobs** — periodic `PpcCredentialHealthQueueable` completions
3. Dashboard — **Last checked** should be within 45 minutes; otherwise the stale warning appears

---

## User guide

### For operators (watch health)

1. Open the Lightning Home page that contains **PPC Credential Health** (or the **PPC Credential Statuses** tab).
2. Green **Healthy** means that subsidiary’s token and transaction account responded 2xx on the last probe.
3. Amber **Unhealthy** is usually a credential or request problem (4xx). Check the named credential password (token) and username (UUID).
4. Red **Other Error** is usually Atlassian 5xx, timeout, or a missing named credential.
5. If every card says status is stale, the schedule is probably not running — use **Start** below or click **Probe now**.
6. **Probe now** if you just rotated a token and do not want to wait up to 20 minutes.

### For admins (install and operate)

1. Deploy the metadata in [Metadata created or changed](#metadata-created-or-changed) (manifest: `manifest/package-ppc-credential-health.xml`).
2. Assign **Atlassian PPC Access** (or grant equivalent object/Apex access).
3. Put **PPC Credential Health** on the Home page in App Builder.
4. Run `PpcCredentialHealthSchedulable.start();` in the target org.
5. Optional: create the Slack Flow described below.
6. Optional: create the org-default **PPC Health Check Settings** record so you can toggle **Enabled** without Apex.

### Adding or removing a subsidiary

**Add:** named credential `Eficode_Office_{CODE}` + `PPC_TransactionAccount__mdt` row (+ picklist value if new). Next probe creates the status row.

**Remove from health check only:** delete or stop using that CMDT record (understand the impact on invoice import). Old `PpcCredentialStatus__c` rows are not auto-deleted.

---

## Slack notifications from a Flow

No Flow is deployed with this feature. The custom object is built so you can add a **record-triggered Flow** in the org that posts to Slack when a **subsidiary’s connection status changes**.

The probe updates `LastChecked__c` every 20 minutes even when nothing is wrong. The Flow must key off **`Status__c`**, not last checked, or the channel will get a message on every probe.

This org already posts to Slack from Flows with the **Send Slack Message** action (`slackPostMessage`), for example **Send Slack Notification to ScandicDeals Channel**. Use the same Slack for Salesforce app and a channel your ops team watches.

### When the Flow should run

| Event | Should Slack fire? |
|---|---|
| Status changes (e.g. Healthy → Unhealthy, Unhealthy → Other Error, Other Error → Healthy) | **Yes** — this is the intended alert |
| Same status, only Last Checked / response time updated | **No** |
| First insert after the first probe (row created already Healthy or Unhealthy) | Optional — `IsChanged` is false on create; add a create path if you want the first failure too |

### Build the Flow (Setup)

1. Setup → **Flows** → **New Flow**.
2. Choose **Record-Triggered Flow**.
3. **Object:** PPC Credential Status (`PpcCredentialStatus__c`).
4. **Trigger:** **A record is created or updated**.
5. **Optimize the Flow for:** **Actions and Related Records** (after save). After-save is required for the Slack action.
6. **Entry conditions** — **Formula evaluates to true**:

```
ISCHANGED({!$Record.Status__c})
```

That is the minimum. It fires on every status change for every subsidiary, with no consecutive-failure filter.

7. (Optional) Narrow it. To alert only when something goes bad or recovers:

```
ISCHANGED({!$Record.Status__c})
&& (
  TEXT({!$Record.Status__c}) = "Unhealthy"
  || TEXT({!$Record.Status__c}) = "Other_Error"
  || TEXT({!$Record.Status__c}) = "Healthy"
)
```

To also notify on the **first** probe if it is already failing (create, not update):

```
ISCHANGED({!$Record.Status__c})
|| (
  ISNEW()
  && TEXT({!$Record.Status__c}) <> "Healthy"
)
```

Do **not** use “Any condition is met” with `LastChecked__c` IsChanged.

8. Add a **Decision** if you want different Slack wording for down vs recovered:
   - Down: `TEXT({!$Record.Status__c})` is `Unhealthy` or `Other_Error`
   - Recovered: current status is `Healthy` and prior was not

9. Add action **Send Slack Message** (`slackPostMessage`). Copy **Slack App Id**, **Slack Workspace Id**, and **Conversation Id** (channel) from an existing working Slack Flow in this org, then change the conversation to the PPC/ops channel.

   Typical inputs:

   | Input | Value |
   |---|---|
   | Slack App Id for token | Same as other Eficode Slack Flows |
   | Slack Workspace Id for token | Same as other Eficode Slack Flows |
   | Slack Conversation Id | The target channel |
   | Slack Message | Formula or text template (below) |
   | Record Id | `{!$Record.Id}` (so Slack can link the Salesforce record if the app supports it) |

10. **Save** (e.g. label `PPC Credential Health Slack`) → **Activate**.

### Suggested Slack message

Create a **Text Template** resource, for example:

```
PPC credential {!$Record.NamedCredentialName__c} ({!$Record.CV_Subsidiary__c})
Status: {!$Record.Status__c}  HTTP: {!$Record.HttpStatusCode__c}
Last success: {!$Record.LastSuccess__c}
Last failure: {!$Record.LastFailure__c}
{!$Record.ErrorMessage__c}
```

Picklist `CV_Subsidiary__c` in a text template shows the API value (`FI`, `Jodocus GmbH`). For the label, use a formula with `TEXT()` / `CASE`, or `ISPICKVAL` if you split channels per subsidiary.

### Per-subsidiary Slack channels (optional)

Add a Decision with `ISPICKVAL({!$Record.CV_Subsidiary__c}, "FI")` (and the other offices), each path calling **Send Slack Message** with a different `slackConversationId`. Same pattern as other Flows that branch on Account subsidiary.

### Test the Flow

1. Open a **PPC Credential Status** record (or use **Probe now** after breaking a sandbox named credential).
2. In Flow Builder, **Debug** on that record, or temporarily change Status on a sandbox row and save (the next probe will overwrite it).
3. Confirm one Slack message when Status changes, and **no** message when only Last Checked changes.

If the channel floods every 20 minutes, the entry condition is matching every update — fix it to `ISCHANGED({!$Record.Status__c})` only.

---

## Metadata created or changed

### New

| Type | API name | Purpose |
|---|---|---|
| Custom object | `PpcCredentialStatus__c` | Latest status per named credential |
| Custom setting (hierarchy) | `PPC_HealthCheckSettings__c` | Scheduled-job kill switch |
| Tab | `PpcCredentialStatus__c` | List/detail of statuses |
| Layout | PPC Credential Status Layout | Record layout |
| Compact layout | `Compact_Layout` | Highlights: name, status, HTTP code, last checked |
| List views | `All`, `Unhealthy` | Operations views |
| LWC | `ppcCredentialHealth` | Home/App dashboard |
| Apex | `PpcCredentialHealthSchedulable` | Register/abort the three cron jobs; enqueue on fire |
| Apex | `PpcCredentialHealthQueueable` | Probe all offices; upsert status |
| Apex | `PpcCredentialHealthController` | LWC `getStatuses` / `probeNow` |
| Apex tests | `*Test` for the three classes above | Coverage |
| Script | `scripts/start_ppc_health_schedule.apex` | Convenience `start()` |
| Manifest | `manifest/package-ppc-credential-health.xml` | Targeted deploy |

`PpcCredentialStatus__c` fields: `NamedCredentialName__c`, `CV_Subsidiary__c`, `TransactionAccountId__c`, `Status__c` (history tracked), `HttpStatusCode__c`, `LastChecked__c`, `LastSuccess__c`, `LastFailure__c`, `ErrorMessage__c`, `ConsecutiveFailures__c`, `ResponseTimeMs__c`.

Sharing: org-wide **Public Read Only**. **Atlassian PPC Access** has Read + View All on the object; create/update is done by Apex (`without sharing` on the Queueable).

### Changed (existing)

| Type | API name | Change |
|---|---|---|
| Apex | `PortalCommerceApiClient` | `probeOffice`, status constants, 10s timeout, body truncate |
| Apex | `PortalCommerceApiAccessMgmt` | `getNamedCredentialDeveloperName`; safer missing-credential check |
| Apex test | `PortalCommerceApiClientTest` | Probe and mapping tests |
| Permission set | `Atlassian_PPC_Access` | Class, object, field, and tab access |
| Manifest | `manifest/package.xml` | Members for the new object, setting, tab, and layout |

### Reused (not created for this feature)

- Named credentials `Eficode_Office_*`
- Custom metadata `PPC_TransactionAccount__mdt`
- Custom permissions `Eficode_Office_*` (not used by the probe itself)

---

## Deploy

Temporary package: `manifest/package-ppc-credential-health.xml`.

Validation only:

```bash
sf project deploy start \
  --manifest manifest/package-ppc-credential-health.xml \
  --target-org EficodeProd \
  --dry-run \
  --test-level RunSpecifiedTests \
  --tests PortalCommerceApiClientTest \
  --tests PpcCredentialHealthControllerTest \
  --tests PpcCredentialHealthQueueableTest \
  --tests PpcCredentialHealthSchedulableTest \
  --wait 30
```

Omit `--dry-run` for a real deploy. After deploy, `start()` the jobs and add the LWC to Home if it is not already on the page. Scheduled Apex is **not** created by metadata deploy.

---

## Troubleshooting

| Symptom | What to check |
|---|---|
| Stale warning on all cards | Jobs not scheduled, kill switch off, or Queueable failing. Setup → Scheduled Jobs / Apex Jobs. Click **Probe now**. |
| **Probe now** says a check is already running | Previous Queueable still queued or processing. Wait, or inspect Apex Jobs. |
| One office Unhealthy (4xx) | Named credential token (password) or transaction account UUID (username). Compare with `PPC_TransactionAccount__mdt` master label. |
| One office Other Error, HTTP 0 | Missing named credential, timeout, or callout exception. Error Message on the record. |
| Scheduled jobs never enqueue | Org-default **Enabled** is unchecked. |
| `System.schedule` error about seconds/minutes | Do not use `0 0,20,40 * * * ?`. Use `PpcCredentialHealthSchedulable.start()`. |
| Slack flooding | Flow is firing on `LastChecked__c` or every update. Restrict to `Status__c` IsChanged. |
| New office never appears | No CMDT row, or `CV_Subsidiary__c` picklist does not include `SubsidiaryApiName__c` (restricted picklist upsert fails). |
| Dashboard empty after first deploy | No probe has run yet. **Probe now** or `start()`. |
| User cannot see the component or data | Assign **Atlassian PPC Access**; confirm object Read and Apex class access. |

Debug logs: search for `PpcCredentialHealthQueueable` and `PPC health check is disabled`.
