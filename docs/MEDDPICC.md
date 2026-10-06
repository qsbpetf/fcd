# MEDDPICC

Two Lightning components on the Opportunity record page store a MEDDPICC analysis in long text fields and show it back as sections. The importer accepts a JSON file or pasted JSON. The viewer reads the Opportunity fields. It does not read the file.

---

## Table of Contents

1. [Importer](#importer)
2. [JSON shape](#json-shape)
3. [Viewer](#viewer)

---

## Importer

`meddpicImporter` (label **MEDDPICC Importer**) is exposed on a record page. The card title is **Import MEDDPICC into Salesforce Opportunity**.

The user either uploads a `.json` file or pastes JSON, then clicks **Import MEDDPICC**. The button stays disabled until one of those has a value.

Upload uses `lightning-file-upload` against the Opportunity, so Salesforce stores a file, then `MeddpicImporter.getJsonFile` reads `ContentVersion.VersionData` and **deletes the ContentDocument**. The file does not stay on the Opportunity. `contentBodyId` and `oppId` are parameters on that method and are not used. Paste does not create a file.

If the user pastes after an upload, Import uses the pasted text. The file text is used when the textarea is cleared again, or when the user never pasted.

`JSON.parse` runs in the browser. Invalid JSON shows **Invalid JSON** and does not update the Opportunity. A payload without `MEDDPICC_Analysis`, or a missing `recordId`, skips the update with no error toast.

---

## JSON shape

The importer reads `MEDDPICC_Analysis` and these keys:

| JSON key | Opportunity field | Label |
| --- | --- | --- |
| `M_Metrics` | `Metrics__c` | Metrics |
| `E_EconomicBuyer` | `Economic_Buyer__c` | Economic Buyer |
| `D_DecisionCriteria` | `Decision_Criteria__c` | Decision Criteria |
| `D_DecisionProcess` | `Decision_Process__c` | Decision Process |
| `P_PaperProcess` | `Paper_Process__c` | Paper Process |
| `I_ImplicatePain` | `Identify_Pain__c` | Identify Pain |
| `C_Champion` | `Champion__c` | Champion |
| `C_Competition` | `Competition__c` | Competition |

Each section can have `confidence`, `summary`, and `gaps` (a list of strings). The text written to the field is:

```text
Confidence: <confidence>

Summary: <summary>

Gaps:
- <gap>
- <gap>
```

Empty pieces are left out. A section that produces no text is skipped, so that Opportunity field is left as it was. Sections that do produce text are sent together with `updateRecord`. A successful save toasts **Opportunity Updated**. A save error toasts the record error and does not roll back fields that Salesforce accepted. There is one update call, so a failure rejects the whole update.

`Metrics__c` is a long text area of 32,768 characters. The other seven fields are the matching long text areas on Opportunity.

---

## Viewer

`meddpicViewer` (label **MEDDPICC Visualizer**) is exposed on a record page. It loads the eight fields with `getRecord` and parses the text the importer wrote.

| Parsed piece | How |
| --- | --- |
| Confidence | Text after `Confidence:` on that line. Missing text is shown as **Not Provided**. |
| Summary | Text after `Summary:` up to the next blank line |
| Gaps | Lines under `Gaps:`, with a leading `-` removed |

Confidence `green`, `yellow`, and `red` (any case) get the matching badge color. Any other confidence, including **Not Provided**, uses the neutral badge. A blank field is still listed, with no summary and no gaps.
