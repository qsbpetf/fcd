# Opportunity Line Item Column Configuration – Administrator Guide

This guide explains how to manage which columns appear in the Opportunity Products table on Opportunity record pages. You can show or hide columns, change their order, add new columns, and adjust column width—all without writing code.

---

## Table of Contents

1. [What Is This?](#what-is-this)
2. [Where to Manage the Configuration](#where-to-manage-the-configuration)
3. [Understanding the Configuration Records](#understanding-the-configuration-records)
4. [How to Hide (Disable) a Column](#how-to-hide-disable-a-column)
5. [How to Change Column Order](#how-to-change-column-order)
6. [How to Add a New Column](#how-to-add-a-new-column)
7. [How to Delete a Column Configuration](#how-to-delete-a-column-configuration)
8. [Field Reference](#field-reference)
9. [Supported Column Types](#supported-column-types)
10. [Examples by Column Type](#examples-by-column-type)
11. [How to Find Field API Names](#how-to-find-field-api-names)
12. [Troubleshooting](#troubleshooting)

---

## What Is This?

The **Opportunity Products** section on an Opportunity record page shows a table of products (Opportunity Line Items) added to that opportunity. This table has many possible columns, such as Product name, Quantity, Unit Price, Discount, Start Date, and so on.

The **Opportunity Line Item Column Config** lets you control:

- **Which columns are visible** – Show or hide any column
- **Column order** – Decide which columns appear from left to right
- **Column width** – Set how wide each column is
- **Which columns are sortable** – Allow or block sorting by that column

All of this is done through configuration records in Salesforce Setup. No programming is required.

---

## Where to Manage the Configuration

1. Click the **gear icon** (⚙️) in the top-right corner of Salesforce.
2. Click **Setup**.
3. In the Quick Find box (left side), type **Custom Metadata Types**.
4. Click **Custom Metadata Types**.
5. Find **Opportunity Line Item Column Config** in the list.
6. Click **Manage Records** next to it.

You will see a list of configuration records. Each record represents one column that can appear in the table. The records are sorted by **Sort Order** by default.

---

## Understanding the Configuration Records

Each configuration record has these main fields:

| Field | What It Does |
|-------|---------------|
| **Label** | The name shown at the top of the column (e.g. "Unit Price", "Quantity"). |
| **Field API Name** | The technical name of the Salesforce field that provides the data (e.g. `UnitPrice`, `Quantity`). |
| **Type** | How the data is displayed (text, number, currency, date, etc.). |
| **Sort Order** | A number that controls the column position. Lower numbers appear further left. |
| **Is Visible** | Checked = column is shown. Unchecked = column is hidden. |
| **Initial Width** | Column width in pixels (e.g. 150, 200). |
| **Sortable** | Checked = users can click the column header to sort. Unchecked = no sorting. |

Additional fields are used for special column types (currency, picklist, etc.). These are explained in the [Field Reference](#field-reference) section.

---

## How to Hide (Disable) a Column

To hide a column without deleting its configuration:

1. Go to **Setup → Custom Metadata Types → Opportunity Line Item Column Config → Manage Records**.
2. Click the **Label** of the column you want to hide (e.g. "User Count").
3. **Uncheck** the **Is Visible** checkbox.
4. Click **Save**.

The column will no longer appear in the table. To show it again, open the same record and check **Is Visible** again.

---

## How to Change Column Order

Columns are ordered by the **Sort Order** field. Lower numbers appear further to the left.

**To move a column to the left:**

1. Open the configuration record for that column.
2. Change **Sort Order** to a **smaller** number (e.g. from 50 to 20).
3. If another column already has that number, increase the other column’s Sort Order first.
4. Click **Save**.

**To move a column to the right:**

1. Open the configuration record for that column.
2. Change **Sort Order** to a **larger** number (e.g. from 20 to 50).
3. Click **Save**.

**Example:** To move "Discount" before "Unit Price", set Discount’s Sort Order to 35 (Unit Price is 40). Or set Unit Price to 55 and Discount to 50.

**Tip:** Use Sort Order values in steps of 10 (10, 20, 30, 40…) so you can easily insert new columns between existing ones.

---

## How to Add a New Column

To add a new column to the table:

1. Go to **Setup → Custom Metadata Types → Opportunity Line Item Column Config → Manage Records**.
2. Click **New**.
3. Fill in the required fields (see below).
4. Click **Save**.

### Required Fields for a New Column

| Field | What to Enter |
|-------|----------------|
| **Label** | The name you want for the column (e.g. "List Price", "Description"). |
| **Field API Name** | The API name of the field. See [How to Find Field API Names](#how-to-find-field-api-names). |
| **Type** | How the data should be displayed. See [Supported Column Types](#supported-column-types). |
| **Sort Order** | A number for the column position (e.g. 165 if you want it after the last column). |
| **Is Visible** | Checked = show the column. |

### Optional Fields

| Field | When to Use |
|-------|-------------|
| **Initial Width** | Set a width in pixels (e.g. 150). Default is 120 if left blank. |
| **Sortable** | Checked = users can sort by this column. Unchecked = no sorting. Default is checked. |
| **Currency Code** | For **currency** type only. See [Currency columns](#currency-columns). |
| **Type Attributes JSON** | For special column types (discount, url, picklist). See [Examples by Column Type](#examples-by-column-type). |
| **Cell Attributes JSON** | For alignment (e.g. right-align numbers). |

### Examples of Simple New Columns

**Example 1: Add a "List Price" column (currency)**

- Label: `List Price`
- Field API Name: `ListPrice`
- Type: `currency`
- Sort Order: `165`
- Is Visible: checked
- Currency Code: `OPPORTUNITY` (use the opportunity’s currency)

**Example 2: Add a "Description" column (text)**

- Label: `Description`
- Field API Name: `Description`
- Type: `text`
- Sort Order: `165`
- Is Visible: checked
- Initial Width: `200`

**Example 3: Add a "Service Date" column (date)**

- Label: `Service Date`
- Field API Name: `ServiceDate`
- Type: `date-local`
- Sort Order: `165`
- Is Visible: checked

---

## How to Delete a Column Configuration

To remove a column from the configuration:

1. Go to **Setup → Custom Metadata Types → Opportunity Line Item Column Config → Manage Records**.
2. Click the **Label** of the column you want to remove.
3. Click **Delete** (or use the dropdown next to Edit if you don’t see Delete).
4. Confirm the deletion.

The column will no longer appear in the table. To show it again, you must create a new configuration record.

---

## Field Reference

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| **Label** | Text shown as the column header. | `Unit Price` |
| **Field API Name** | The technical name of the field (e.g. from Object Manager). | `UnitPrice` |
| **Type** | How the data is displayed. See [Supported Column Types](#supported-column-types). | `currency` |
| **Sort Order** | A number that controls left-to-right order. Lower = left. | `40` |
| **Is Visible** | Checked = column is shown. Unchecked = column is hidden. | Checked |

### Optional Fields

| Field | Description | When to Use |
|-------|-------------|-------------|
| **Initial Width** | Column width in pixels. | When you want a specific width. |
| **Sortable** | Checked = users can sort by this column. | Uncheck for columns that cannot be sorted. |
| **Currency Code** | For currency columns. | Use `USD`, `EUR`, `GBP`, etc., or `OPPORTUNITY` (use opportunity currency). |
| **Type Attributes JSON** | Extra settings for the column type. | For discount, url, picklist, etc. See examples below. |
| **Cell Attributes JSON** | Cell alignment. | Use `{"alignment":"right"}` for right-aligned numbers. |
| **Picklist Field API Name** | For picklist columns. | The field whose options should be shown (usually same as Field API Name). |
| **Query Field API Names** | For special columns. | Only for Product (URL) and similar columns. |

### Advanced Fields (Use Only When Needed)

| Field | Description | Example |
|-------|-------------|---------|
| **Type Attributes JSON** | JSON for special formatting. | `{"name":"Discount__c"}` for discount columns |
| **Column Key** | Legacy identifier. | Usually left as-is or can be ignored. |

---

## Supported Column Types

Use one of these values in the **Type** field:

| Type | Use For | Example Fields |
|------|---------|----------------|
| `text` | Text | Description, Name, Additional Info |
| `number` | Numbers (decimals) | Quantity |
| `integer` | Whole numbers | User Count |
| `currency` | Money | Unit Price, List Price |
| `percent` | Percentages | Discount (if shown as percent) |
| `date-local` | Dates | Start Date, End Date |
| `boolean` | Yes/No (checkboxes) | Loss Reviewed |
| `picklist` | Dropdown lists | Type (Renewal__c) |
| `url` | Links | Product (URL to record) |
| `discount` | Special discount field | Discount (custom editable) |

---

## Examples by Column Type

### Text columns

| Field | Value |
|-------|-------|
| Type | `text` |
| Field API Name | `Additional_Info__c` |
| Label | `Additional Info` |

No extra fields needed.

---

### Number columns

| Field | Value |
|-------|-------|
| Type | `number` |
| Field API Name | `Quantity` |
| Label | `Quantity` |

---

### Currency columns

| Field | Value |
|-------|-------|
| Type | `currency` |
| Field API Name | `UnitPrice` |
| Label | `Unit Price` |
| Currency Code | `OPPORTUNITY` (use opportunity currency) or `USD`, `EUR`, etc. |

---

### Date columns

| Field | Value |
|-------|-------|
| Type | `date-local` |
| Field API Name | `License_Start_date__c` |
| Label | `Start Date` |

---

### Boolean (checkbox) columns

| Field | Value |
|-------|-------|
| Type | `boolean` |
| Field API Name | `Loss_Reviewed__c` |
| Label | `LIC: Loss Reviewed` |

---

### Picklist columns

| Field | Value |
|-------|-------|
| Type | `picklist` |
| Field API Name | `Renewal__c` |
| Label | `Type` |
| Picklist Field API Name | `Renewal__c` |
| Type Attributes JSON | `{"name":"Renewal__c","placeholder":"Select Type..."}` |

---

### Discount column (special type)

| Field | Value |
|-------|-------|
| Type | `discount` |
| Field API Name | `Discount__c` |
| Label | `Discount` |
| Type Attributes JSON | `{"name":"Discount__c"}` |
| Cell Attributes JSON | `{"alignment":"right"}` |

---

### Product column (URL to record)

The Product column is special. It shows a link to the record. Do not create a new Product column manually; use the existing one. If you need a similar column, contact your Salesforce administrator or developer.

---

## How to Find Field API Names

To add a column, you need the **Field API Name** of the field.

1. Go to **Setup**.
2. In Quick Find, type **Object Manager**.
3. Click **Object Manager**.
4. Search for **Opportunity Line Item** (or **Opportunity Product**).
5. Click **Opportunity Line Item**.
6. Open **Fields & Relationships**.
7. Find the field you want. The **API Name** is shown (e.g. `UnitPrice`, `Quantity`, `Discount__c`).

**Custom fields** usually end with `__c` (e.g. `Additional_Info__c`).

**Product-related fields** use the format `PricebookEntry.Product2.FieldName` (e.g. `PricebookEntry.Product2.Unit_of_Measure__c`).

---

## Troubleshooting

### A column does not appear after I added it

- Check that **Is Visible** is checked.
- Check that **Field API Name** is correct (no typos, correct `__c` for custom fields).
- Ensure the field exists on Opportunity Line Item.
- Refresh the Opportunity page.

### A column shows no data

- **Field API Name** may be wrong. Check the field name in Object Manager.
- The field might not exist on the product or might be empty.
- For Product-related fields, use the format `PricebookEntry.Product2.FieldName`.

### A column appears in the wrong position

- Adjust **Sort Order**. Lower numbers appear further left.
- Use values like 10, 20, 30 so you can insert new columns between them.

### I cannot change a configuration record

- You need **Custom Metadata Types** edit permission.
- Check that the record is not protected.
- Contact your Salesforce administrator if you still cannot edit.

### Changes do not appear on the page

- Refresh the Opportunity page (F5 or Ctrl+R).
- Clear the browser cache.
- Wait a few seconds; changes may take a moment to propagate.

### I added a currency column but it shows wrong currency

- Set **Currency Code** to `OPPORTUNITY` to use the opportunity’s currency.
- Or set it to a specific code like `USD`, `EUR`, or `GBP`.

---

## Summary

| Task | Steps |
|------|-------|
| **Hide a column** | Open the record → Uncheck **Is Visible** → Save |
| **Show a column** | Open the record → Check **Is Visible** → Save |
| **Change order** | Open the record → Change **Sort Order** (lower = left) → Save |
| **Add a column** | Manage Records → New → Fill Label, Field API Name, Type, Sort Order, Is Visible → Save |
| **Delete a column** | Open the record → Delete → Confirm |

All changes are managed in **Setup → Custom Metadata Types → Opportunity Line Item Column Config → Manage Records**. No code is required.
