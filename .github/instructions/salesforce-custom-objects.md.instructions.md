---
applyTo: "**"
---

## Apply when creating Salesforce Custom Objects and Fields

# 🧩 Salesforce Custom Object Source Structure

This document describes the **source structure and XML layout** for **Custom Objects** in Salesforce Metadata API and SFDX source format.

---

## 📁 Folder Structure Overview

In Salesforce, all metadata is stored in an organized folder hierarchy. For **Custom Objects**, the structure resides under the `/objects` directory.

### Example Directory Tree

```plaintext
force-app/
└── main/
    └── default/
        ├── objects/
        │   ├── Invoice__c/
        │   │   ├── Invoice__c.object
        │   │   ├── fields/
        │   │   │   ├── Amount__c.field-meta.xml
        │   │   │   ├── Status__c.field-meta.xml
        │   │   │   └── BillingAddress__c.field-meta.xml
        │   │   ├── listViews/
        │   │   │   └── All_Invoices.listView-meta.xml
        │   │   ├── recordTypes/
        │   │   │   └── Invoice_RecordType.recordType-meta.xml
        │   │   ├── validationRules/
        │   │   │   └── Validate_Amount.validationRule-meta.xml
        │   │   ├── compactLayouts/
        │   │   │   └── Invoice_Compact.compactLayout-meta.xml
        │   │   ├── webLinks/
        │   │   │   └── Open_Invoice.weblink-meta.xml
        │   │   └── sharingReasons/
        │   │       └── SharedByOwner.sharingReason-meta.xml
        │   └── Product__c/
        │       └── Product__c.object
        └── layouts/
            └── Invoice__c-Invoice Layout.layout-meta.xml
```

---

## 🧱 Key Components

### 1. `CustomObject` File (`<ObjectName>.object`)

The core definition of the object, containing general metadata like labels, sharing model, and Name field.

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Invoice</label>
    <pluralLabel>Invoices</pluralLabel>
    <nameField>
        <label>Invoice Number</label>
        <type>AutoNumber</type>
        <displayFormat>INV-{0000}</displayFormat>
    </nameField>
    <deploymentStatus>Deployed</deploymentStatus>
    <sharingModel>ReadWrite</sharingModel>
</CustomObject>
```

**Location:** `/objects/Invoice__c/Invoice__c.object`

**Defines:**

- Object labels
- API name (`__c` suffix)
- Name field configuration
- Deployment and sharing options
- Child references to record types, validation rules, etc.

---

### 2. Fields (`fields/*.field-meta.xml`)

Each field has its own XML file under the `fields/` directory.

#### Example – Text Field

```xml
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Comments__c</fullName>
    <label>Comments</label>
    <type>LongTextArea</type>
    <length>32000</length>
    <visibleLines>30</visibleLines>
</CustomField>
```

#### Example – Picklist Field

```xml
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Status__c</fullName>
    <label>Status</label>
    <type>Picklist</type>
    <valueSet>
        <valueSetDefinition>
            <sorted>false</sorted>
            <value>
                <fullName>Draft</fullName>
                <default>true</default>
            </value>
            <value>
                <fullName>Paid</fullName>
            </value>
        </valueSetDefinition>
    </valueSet>
</CustomField>
```

#### Example – Address Field

```xml
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>BillingAddress__c</fullName>
    <label>Billing Address</label>
    <type>Address</type>
</CustomField>
```

---

### 3. Record Types (`recordTypes/*.recordType-meta.xml`)

Defines different configurations for subsets of records.

```xml
<RecordType xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Invoice_RecordType</fullName>
    <label>Standard Invoice</label>
    <active>true</active>
</RecordType>
```

---

### 4. Validation Rules (`validationRules/*.validationRule-meta.xml`)

Logic checks for data integrity.

```xml
<ValidationRule xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Validate_Amount</fullName>
    <active>true</active>
    <errorConditionFormula>Amount__c &lt;= 0</errorConditionFormula>
    <errorMessage>Amount must be greater than zero.</errorMessage>
</ValidationRule>
```

---

### 5. List Views (`listViews/*.listView-meta.xml`)

Define record list filters and columns.

```xml
<ListView xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>All_Invoices</fullName>
    <label>All Invoices</label>
    <filterScope>Everything</filterScope>
    <columns>NAME</columns>
    <columns>Amount__c</columns>
</ListView>
```

---

### 6. Layouts (`layouts/*.layout-meta.xml`)

Stored globally under `/layouts/`. Layouts define how fields and sections appear on record pages.

```xml
<Layout xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>Invoice__c-Invoice Layout</fullName>
    <layoutSections>
        <label>Invoice Information</label>
        <layoutColumns>
            <layoutItems>
                <field>Amount__c</field>
            </layoutItems>
            <layoutItems>
                <field>Status__c</field>
            </layoutItems>
        </layoutColumns>
    </layoutSections>
</Layout>
```

---

# Salesforce Field Creation Guide (Metadata API)

This guide explains how to create fields in Salesforce using **Metadata API XML**, the **supported data types**, key **characteristics/constraints**, and a **minimal XML snippet for each type**. Examples target API v65.0 unless noted.

> **Conventions**
>
> - Custom fields end with `__c`. Put them inside the `.object` file for the target object (e.g., `objects/MyObject__c.object`).
> - Use `<fullName>`, `<label>`, and `<type>` in every field. Optional properties vary by type.
> - For picklists, use `<valueSet>` (API 38.0+) instead of legacy `<picklist>`.
> - Standard picklists are defined via **StandardValueSet**, not via `CustomField`.

---

## 1) Text

**Key props:** `length` (1–255 typical), `unique` (optional), `required` (optional).

```xml
<fields>
  <fullName>MyText__c</fullName>
  <label>My Text</label>
  <type>Text</type>
  <length>100</length>
  <required>false</required>
  <unique>false</unique>
</fields>
```

---

## 2) Text Area (Long Text)

**Key props:** `length` (up to 32,000), `visibleLines` (UI height).

```xml
<fields>
  <fullName>Comments__c</fullName>
  <label>Comments</label>
  <type>LongTextArea</type>
  <length>32000</length>
  <visibleLines>30</visibleLines>
</fields>
```

---

## 3) Number

**Key props:** `precision` (total digits), `scale` (decimal places), `unique`, `required`.

```xml
<fields>
  <fullName>OrderQty__c</fullName>
  <label>Order Qty</label>
  <type>Number</type>
  <precision>18</precision>
  <scale>0</scale>
  <required>false</required>
  <unique>false</unique>
</fields>
```

---

## 4) Percent

Same shape as **Number** (stored as decimal).

```xml
<fields>
  <fullName>DiscountPct__c</fullName>
  <label>Discount %</label>
  <type>Percent</type>
  <precision>5</precision>
  <scale>2</scale>
</fields>
```

---

## 5) Currency

Same shape as **Number** with currency semantics.

```xml
<fields>
  <fullName>Amount__c</fullName>
  <label>Amount</label>
  <type>Currency</type>
  <precision>16</precision>
  <scale>2</scale>
</fields>
```

---

## 6) Checkbox

```xml
<fields>
  <fullName>IsActive__c</fullName>
  <label>Is Active</label>
  <type>Checkbox</type>
  <!-- Optional: defaultValue e.g., <defaultValue>true</defaultValue> -->
</fields>
```

---

## 7) Date / 8) DateTime

```xml
<!-- Date -->
<fields>
  <fullName>GoLiveDate__c</fullName>
  <label>Go Live Date</label>
  <type>Date</type>
</fields>

<!-- DateTime -->
<fields>
  <fullName>ReviewedAt__c</fullName>
  <label>Reviewed At</label>
  <type>DateTime</type>
</fields>
```

---

## 9) Email / 10) Phone / 11) URL

```xml
<!-- Email -->
<fields>
  <fullName>ContactEmail__c</fullName>
  <label>Contact Email</label>
  <type>Email</type>
</fields>

<!-- Phone -->
<fields>
  <fullName>SupportPhone__c</fullName>
  <label>Support Phone</label>
  <type>Phone</type>
</fields>

<!-- URL -->
<fields>
  <fullName>ResourceUrl__c</fullName>
  <label>Resource URL</label>
  <type>Url</type>
</fields>
```

---

## 12) Picklist (single-select)

Use `<valueSet>` for custom picklists. To reuse a **StandardValueSet** (e.g., Industry), manage that via `StandardValueSet` metadata, not here.

```xml
<fields>
  <fullName>Status__c</fullName>
  <label>Status</label>
  <type>Picklist</type>
  <valueSet>
    <valueSetDefinition>
      <sorted>true</sorted>
      <value>
        <fullName>New</fullName>
        <default>false</default>
        <label>New</label>
      </value>
      <value>
        <fullName>InProgress</fullName>
        <default>true</default>
        <label>In Progress</label>
      </value>
      <value>
        <fullName>Closed</fullName>
        <default>false</default>
        <label>Closed</label>
      </value>
    </valueSetDefinition>
  </valueSet>
</fields>
```

---

## 13) Picklist (Multi-Select)

Same `<valueSet>` structure; use `<type>MultiselectPicklist</type>`.

```xml
<fields>
  <fullName>Tags__c</fullName>
  <label>Tags</label>
  <type>MultiselectPicklist</type>
  <valueSet>
    <valueSetDefinition>
      <sorted>false</sorted>
      <value><fullName>Red</fullName><label>Red</label><default
        >false</default></value>
      <value><fullName>Green</fullName><label>Green</label><default
        >false</default></value>
      <value><fullName>Blue</fullName><label>Blue</label><default
        >false</default></value>
    </valueSetDefinition>
  </valueSet>
</fields>
```

> **Dependent picklists:** Configure dependencies via `<valueSet>…<controllingField>…</controllingField>…</valueSet>` on the dependent field.

---

## 14) Lookup Relationship

**Key props:** `referenceTo`, `relationshipName`, `relationshipLabel`, optional `deleteConstraint` (cascade or restrict), and optional `<lookupFilter>` for runtime filtering.

```xml
<fields>
  <fullName>Account_Lookup__c</fullName>
  <label>Account</label>
  <type>Lookup</type>
  <referenceTo>Account</referenceTo>
  <relationshipName>Accounts</relationshipName>
  <relationshipLabel>Accounts</relationshipLabel>
  <!-- Optional lookup filter -->
  <!--
  <lookupFilter>
    <active>true</active>
    <isOptional>false</isOptional>
    <filterItems>
      <field>Account.IsActive__c</field>
      <operation>equals</operation>
      <value>true</value>
    </filterItems>
  </lookupFilter>
  -->
</fields>
```

> **External lookup:** Use when targeting an **external object** (`*.object` of type external).

```xml
<fields>
  <fullName>ProductRef__c</fullName>
  <label>Product Ref</label>
  <type>ExternalLookup</type>
  <length>20</length>
  <referenceTo>Products__x</referenceTo>
  <relationshipName>Products</relationshipName>
  <relationshipLabel>Products</relationshipLabel>
</fields>
```

---

## 15) Formula

**Key props:** `formula`, `type` (result type), optional `scale`, and `formulaTreatBlankAs` (`BlankAsBlank` or `BlankAsZero`).

```xml
<fields>
  <fullName>NetAmount__c</fullName>
  <label>Net Amount</label>
  <type>Formula</type>
  <formula>Amount__c - (Amount__c * DiscountPct__c / 100)</formula>
  <formulaTreatBlankAs>BlankAsZero</formulaTreatBlankAs>
  <!-- Result type and precision for numeric results -->
  <scale>2</scale>
</fields>
```

Set the result type by the `<type>` value, e.g., `Number`, `Currency`, `Text`, `Date`, `DateTime`, `Boolean`.

---

## 16) File / HTML (Knowledge & specific contexts)

For Knowledge ArticleType custom fields you can use `File` or `Html`. (General orgs typically use Content/Files objects for files.)

```xml
<fields>
  <fullName>Attachment__c</fullName>
  <label>Attachment</label>
  <type>File</type>
</fields>
```

---

## 17) Packaging in `package.xml`

- Retrieve custom fields only:

```xml
<types>
  <members>MyObject__c.MyField__c</members>
  <name>CustomField</name>
</types>
```

- Retrieve standard picklist **value sets** (API 38.0+):

```xml
<types>
  <members>Industry</members>
  <name>StandardValueSet</name>
</types>
```

---

## 18) Tips & Gotchas

- Always suffix custom field API names with `__c`.
- Use **StandardValueSet** for standard picklists (e.g., `Industry`, `SalesTeamRole`), not `CustomField`.
- On relationship fields, permissions sometimes reference without the `Id` suffix (e.g., `Contact.Account`).
- Knowledge/ArticleType custom fields share many properties with object fields but are scoped to the `__kav` object.
- For deployments, include the parent object in your source where needed.

---

## 19) Minimal Field Boilerplate

```xml
<fields>
  <fullName>FieldName__c</fullName>
  <label>Field Label</label>
  <type>Text</type>
  <!-- type-specific properties here -->
</fields>
```

---

### Appendix: Common Property Reference (by type)

- **Text**: `length`, `unique`, `required`
- **LongTextArea**: `length`, `visibleLines`
- **Number/Percent/Currency**: `precision`, `scale`, `required`, `unique`
- **Checkbox**: `defaultValue` (optional)
- **Date/DateTime**: _(none required beyond `type`)_
- **Email/Phone/Url**: _(none required beyond `type`)_
- **Picklist/MultiselectPicklist**: `valueSet` (definitions or global value set)
- **Lookup**: `referenceTo`, `relationshipName`, `relationshipLabel`, `deleteConstraint` (optional), `lookupFilter` (optional)
- **ExternalLookup**: `length`, `referenceTo` (external object), `relationship*`
- **Formula**: `formula`, `type` (result), `scale` (for numeric), `formulaTreatBlankAs`

---

## 🧩 Metadata API vs. SFDX Source Format

| Aspect           | Metadata API (zip)                                   | SFDX Source Format                                   |
| ---------------- | ---------------------------------------------------- | ---------------------------------------------------- |
| File Packaging   | All fields inside one `.object` file                 | Each field has its own `.field-meta.xml`             |
| Folder Structure | Flat structure inside `unpackaged/`                  | Nested under `force-app/main/default/objects/`       |
| Deployment       | Deployed via `ant deployCode` or `sf project deploy` | Pushed or pulled using `source:push` / `source:pull` |

---

## 🔗 References

- **Salesforce Metadata API Developer Guide** (v65.0, Winter '26)
- **Metadata Types Reference:** `CustomObject`, `CustomField`, `RecordType`, `Layout`, `ValidationRule`
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)

---

**Author:** Salesforce Metadata Documentation Generator  
**Version:** 1.0 (2025-10-16)
