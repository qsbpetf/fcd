# Metadata-Driven OLI Column Configuration – Plan

## Goal

Store full column configuration in Custom Metadata so admins can add, change, or remove any OLI field without code changes. JavaScript builds the column structure from metadata.

---

## 1. Custom Metadata Type – New Fields

Extend `OpportunityLineItemColumnConfig__mdt` with:

| Field | Type | Purpose |
|-------|------|---------|
| `FieldApiName__c` | Text(255) | API name (e.g. `Discount__c`, `Quantity`, `PricebookEntry.Product2.Name`) |
| `Label__c` | Text(255) | Column label |
| `Type__c` | Text(50) | lightning-datatable type: `text`, `number`, `currency`, `percent`, `date-local`, `boolean`, `url`, `picklist`, `integer`, `discount` |
| `SortOrder__c` | Number | Display order (unchanged) |
| `IsVisible__c` | Checkbox | Show/hide (unchanged) |
| `InitialWidth__c` | Number | Column width (optional) |
| `Sortable__c` | Checkbox | Whether sortable (default true) |
| `TypeAttributesJson__c` | Text(255) | JSON for type-specific attributes (Custom Metadata max 255) |
| `CellAttributesJson__c` | Text(255) | JSON for cell attributes (e.g. `{"alignment": "right"}`) |
| `CurrencyCode__c` | Text(20) | For currency: `USD`, `EUR`, or `OPPORTUNITY` (use opportunity currency) |
| `PicklistFieldApiName__c` | Text(255) | For picklist: field to fetch options for (e.g. `Renewal__c`) |
| `QueryFieldApiNames__c` | Text(255) | Comma-separated SOQL fields for this column. Used when display field differs from query fields (e.g. Product URL). |

**Deprecate:** `ColumnKey__c` – keep for migration, but `FieldApiName__c` becomes the primary identifier.

---

## 2. TypeAttributesJson Examples

| Type | Example JSON |
|------|--------------|
| `discount` | `{"name": "Discount__c"}` |
| `url` | `{"label": {"fieldName": "PricebookEntry.Product2.Name"}, "tooltip": {"fieldName": "PricebookEntry.Product2.Name"}}` |
| `picklist` | `{"name": "Renewal__c", "placeholder": "Select Type..."}` (options come from PicklistFieldApiName__c) |
| `currency` | `{"currencyCode": "USD"}` or `{"currencyCode": "OPPORTUNITY"}` – JS resolves `OPPORTUNITY` at runtime |

---

## 3. JavaScript – Build Column Config from Metadata

```javascript
// Pseudocode for handleOpportunityLineItemColumnsSet() or buildColumnsFromConfig()
function buildColumnFromMetadata(config, opportunity, picklistOptionsByField) {
    const col = {
        label: config.label,
        fieldName: config.fieldApiName,
        type: config.type,
        initialWidth: config.initialWidth ?? 120,
        sortable: config.sortable ?? true
    };

    // Type-specific attributes
    if (config.typeAttributesJson) {
        col.typeAttributes = JSON.parse(config.typeAttributesJson);
    }
    if (config.type === 'currency' && config.currencyCode) {
        col.typeAttributes = col.typeAttributes || {};
        col.typeAttributes.currencyCode = config.currencyCode === 'OPPORTUNITY'
            ? opportunity?.CurrencyIsoCode
            : config.currencyCode;
    }
    if (config.type === 'picklist' && config.picklistFieldApiName) {
        col.typeAttributes = col.typeAttributes || {};
        col.typeAttributes.options = picklistOptionsByField[config.picklistFieldApiName] ?? [];
        col.typeAttributes.name = config.fieldApiName;
    }
    if (config.cellAttributesJson) {
        col.cellAttributes = JSON.parse(config.cellAttributesJson);
    }

    return col;
}
```

- Remove `MASTER_COLUMN_DEFINITIONS` and `DEFAULT_COLUMN_KEYS`.
- `buildColumnsFromConfig()`: map each visible metadata record to a column config.
- Add generic `getPicklistValues(fieldApiName)` in Apex if needed for multiple picklist fields.

---

## 4. Apex – Dynamic Field Handling

**getColumnConfig()**

- Return full metadata: `FieldApiName__c`, `Label__c`, `Type__c`, `SortOrder__c`, `IsVisible__c`, `InitialWidth__c`, `Sortable__c`, `TypeAttributesJson__c`, `CellAttributesJson__c`, `CurrencyCode__c`, `PicklistFieldApiName__c`, `QueryFieldApiNames__c`.
- Support both `ColumnKey__c` (legacy) and `FieldApiName__c` (new).

**getOpportunityLineItems()**

- Accept `List<String> fieldApiNames` instead of `columnKeys`.
- For each field, resolve SOQL fields:
  - If `QueryFieldApiNames__c` is set: use it (split by comma).
  - Else: use `FieldApiName__c` (with special handling for `Url` → query `PricebookEntry.Product2.Name`, etc.).
- Validate field paths against Schema (whitelist or describe).
- Build dynamic SOQL from validated fields.

**Field validation**

- Option A: Whitelist from Schema (describe all OLI + Product2 fields).
- Option B: Whitelist from Custom Metadata (e.g. `OLI_Queryable_Fields__mdt`).
- Option C: Validate via Schema.describe at runtime (more flexible, slower).

---

## 5. Special Cases

| Case | FieldApiName | QueryFieldApiNames | TypeAttributesJson |
|------|--------------|--------------------|-------------------|
| Product (URL) | `Url` | `PricebookEntry.Product2.Name,PricebookEntry.Product2.Id,PricebookEntry.Id` | `{"label":{"fieldName":"PricebookEntry.Product2.Name"},"tooltip":{"fieldName":"PricebookEntry.Product2.Name"}}` |
| Discount | `Discount__c` | (same) | `{"name":"Discount__c"}` |
| Currency (opp) | `UnitPrice` | (same) | `{"currencyCode":"OPPORTUNITY"}` |
| Picklist | `Renewal__c` | (same) | `{"name":"Renewal__c","placeholder":"Select Type..."}` + PicklistFieldApiName__c |

---

## 6. Migration

1. Add new fields to `OpportunityLineItemColumnConfig__mdt`.
2. Update existing 16 records with `FieldApiName__c`, `Label__c`, `Type__c`, etc.
3. Update Apex to use `FieldApiName__c` and `QueryFieldApiNames__c`.
4. Update LWC to build columns from metadata.
5. Remove `MASTER_COLUMN_DEFINITIONS`, `COLUMN_KEY_TO_FIELDS`, `DEFAULT_COLUMN_KEYS`.

---

## 7. Files to Change

| File | Changes |
|------|---------|
| `OpportunityLineItemColumnConfig__mdt` | Add 8 new fields |
| 16 `OpportunityLineItemColumnConfig.*.md-meta.xml` | Populate new fields |
| `OpportunityLineItemController.cls` | getColumnConfig returns full config; getOpportunityLineItems uses fieldApiNames; validate fields |
| `opportunityLineItemList.js` | Remove MASTER_COLUMN_DEFINITIONS; add buildColumnsFromMetadata(); wire generic picklist if needed |

---

## 8. Admin Workflow

1. Setup → Custom Metadata Types → Opportunity Line Item Column Config.
2. New record: set `FieldApiName__c` (e.g. `ListPrice`), `Label__c`, `Type__c` (`currency`), `SortOrder__c`, `IsVisible__c`, `CurrencyCode__c` (`OPPORTUNITY`).
3. For special columns: set `TypeAttributesJson__c` and `QueryFieldApiNames__c` as needed.
4. Save and deploy.

No code changes required for new columns.
