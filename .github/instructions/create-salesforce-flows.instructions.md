---
applyTo: "**/*.flow-meta.xml"
---

# Salesforce Flow XML — Complete Authoring Guide

## 1. Overview

Salesforce **Flow** metadata defines the structure, logic, and runtime configuration of a Flow. This file determines how screens, decisions, assignments, loops, and record operations behave.

Each Flow is stored as an XML file and can be deployed or retrieved through the Metadata API or Salesforce DX.

---

## 2. File Structure

- **Folder:** `flows/`
- **File Extension:** `.flow`
- **API Name:** Matches the Flow API name in Salesforce (e.g., `MyFlow.flow`)

### Related Metadata

| Metadata Type      | Folder             | Suffix            | Description                                            |
| ------------------ | ------------------ | ----------------- | ------------------------------------------------------ |
| **FlowDefinition** | `flowDefinitions/` | `.flowDefinition` | Stores active version number and description.          |
| **FlowCategory**   | `flowCategories/`  | `.flowCategory`   | Groups flows into categories.                          |
| **FlowTest**       | `flowtests/`       | `.flowtest`       | Defines flow test metadata for record-triggered flows. |

---

## 3. Basic XML Structure

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
  <apiVersion>65.0</apiVersion>
  <label>Example Flow</label>
  <processType>AutoLaunchedFlow</processType>
  <runInMode>SystemModeWithoutSharing</runInMode>
  <status>Active</status>

  <start>
    <locationX>0</locationX>
    <locationY>0</locationY>
    <connector>
      <targetReference>StartAssignment</targetReference>
    </connector>
  </start>
</Flow>
```

---

## 4. Flow Core Elements

### 4.1 Variables

Variables store data across the Flow.

```xml
<variables>
  <name>varAccountId</name>
  <dataType>String</dataType>
  <isCollection>false</isCollection>
  <isInput>true</isInput>
  <isOutput>false</isOutput>
</variables>
```

| Field          | Description                                                 |
| -------------- | ----------------------------------------------------------- |
| `name`         | API name of the variable.                                   |
| `dataType`     | Data type (String, Boolean, Number, Record, SObject, etc.). |
| `isCollection` | Whether it’s a list/collection.                             |
| `isInput`      | Whether the variable can receive input values.              |
| `isOutput`     | Whether the variable exposes values externally.             |

---

### 4.2 Constants

```xml
<constants>
  <name>constMaxAttempts</name>
  <dataType>Number</dataType>
  <value>3</value>
</constants>
```

---

### 4.3 Formulas

```xml
<formulas>
  <name>frmDiscount</name>
  <dataType>Number</dataType>
  <expression>IF({!Total} > 1000, 0.1, 0)</expression>
</formulas>
```

---

### 4.4 Screens

Screens gather user input or display information.

```xml
<screens>
  <name>Screen1</name>
  <label>Customer Information</label>
  <allowBack>true</allowBack>
  <allowFinish>true</allowFinish>
  <locationX>150</locationX>
  <locationY>200</locationY>
  <fields>
    <name>txtCustomerName</name>
    <fieldType>Text</fieldType>
    <isRequired>true</isRequired>
  </fields>
</screens>
```

---

### 4.5 Decisions

```xml
<decisions>
  <name>Decision_CheckAmount</name>
  <label>Check Amount</label>
  <defaultConnectorLabel>Default</defaultConnectorLabel>
  <rules>
    <name>HighValue</name>
    <conditionLogic>and</conditionLogic>
    <conditions>
      <leftValueReference>varAmount</leftValueReference>
      <operator>GreaterThan</operator>
      <rightValue>1000</rightValue>
    </conditions>
    <connector>
      <targetReference>Screen1</targetReference>
    </connector>
  </rules>
</decisions>
```

---

### 4.6 Assignments

```xml
<assignments>
  <name>AssignDiscount</name>
  <label>Assign Discount</label>
  <locationX>200</locationX>
  <locationY>300</locationY>
  <assignmentItems>
    <assignToReference>varDiscount</assignToReference>
    <operator>Assign</operator>
    <value>10</value>
  </assignmentItems>
  <connector>
    <targetReference>Screen1</targetReference>
  </connector>
</assignments>
```

---

### 4.7 Record Operations

#### Record Lookup

```xml
<recordLookups>
  <name>FindAccount</name>
  <label>Find Account</label>
  <locationX>300</locationX>
  <locationY>400</locationY>
  <assignNullValuesIfNoRecordsFound>false</assignNullValuesIfNoRecordsFound>
  <filterLogic>and</filterLogic>
  <filters>
    <field>Id</field>
    <operator>EqualTo</operator>
    <value>{!varAccountId}</value>
  </filters>
  <outputAssignments>
    <assignToReference>varAccountName</assignToReference>
    <field>Account.Name</field>
  </outputAssignments>
</recordLookups>
```

#### Record Create

```xml
<recordCreates>
  <name>CreateAccount</name>
  <label>Create Account</label>
  <locationX>400</locationX>
  <locationY>400</locationY>
  <assignRecordIdToReference>varNewAccountId</assignRecordIdToReference>
  <inputAssignments>
    <field>Name</field>
    <value>{!varAccountName}</value>
  </inputAssignments>
</recordCreates>
```

---

### 4.8 Loops

```xml
<loops>
  <name>Loop_Contacts</name>
  <label>Loop through Contacts</label>
  <collectionReference>varContacts</collectionReference>
  <iterationOrder>Asc</iterationOrder>
  <locationX>600</locationX>
  <locationY>200</locationY>
  <nextValueConnector>
    <targetReference>AssignDiscount</targetReference>
  </nextValueConnector>
</loops>
```

---

### 4.9 Subflows

```xml
<subflows>
  <name>Subflow_CreateCase</name>
  <label>Call Create Case Subflow</label>
  <flowName>CreateCaseSubflow</flowName>
  <inputAssignments>
    <name>inputAccountId</name>
    <value>{!varAccountId}</value>
  </inputAssignments>
  <outputAssignments>
    <assignToReference>varCaseId</assignToReference>
    <value>{!outputCaseId}</value>
  </outputAssignments>
</subflows>
```

---

### 4.10 Text Templates

```xml
<textTemplates>
  <name>Template_Welcome</name>
  <text>Welcome, {!varCustomerName}!</text>
</textTemplates>
```

---

## 5. Activation and Versioning

- **Activate** a flow by setting `<status>Active</status>`.
- Versions are managed automatically; to reference a specific version, you can name the file `MyFlow-3.flow`.
- The associated **FlowDefinition** determines which version is active globally.

Example FlowDefinition:

```xml
<FlowDefinition xmlns="http://soap.sforce.com/2006/04/metadata">
  <activeVersionNumber>3</activeVersionNumber>
  <description>Flow that creates an account record</description>
  <masterLabel>MyFlow</masterLabel>
</FlowDefinition>
```

---

## 6. Deployment Notes

- **Flows** must be deployed with their **FlowDefinition** for activation unless activated via UI.
- **Managed Package Flows** cannot be modified unless marked as templates.
- Always verify `<apiVersion>` compatibility with your org.

---

## 7. Example Full Flow File

A simple auto-launched flow creating an Account record:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
  <apiVersion>65.0</apiVersion>
  <label>Create Account Example</label>
  <processType>AutoLaunchedFlow</processType>
  <status>Active</status>

  <variables>
    <name>varAccountName</name>
    <dataType>String</dataType>
    <isInput>true</isInput>
  </variables>

  <recordCreates>
    <name>Create_Account</name>
    <label>Create Account</label>
    <assignRecordIdToReference>varAccountId</assignRecordIdToReference>
    <inputAssignments>
      <field>Name</field>
      <value>{!varAccountName}</value>
    </inputAssignments>
  </recordCreates>

  <start>
    <locationX>0</locationX>
    <locationY>0</locationY>
    <connector>
      <targetReference>Create_Account</targetReference>
    </connector>
  </start>
</Flow>
```

---

© 2025 Salesforce Metadata Documentation — Authoring Guide for Flow XML Files
