# Session Evaluation App – Data Import Strategy

## 1. Scope

Covers ingestion of Speakers and Sessions (with primary & optional co-speaker) from a Google Sheet into Salesforce, establishing relationships and ensuring data cleanliness before evaluator assignment.

## 2. Source Sheet Structure (Recommended Tabs)

| Tab      | Key Columns                                                                                                                                                                                                                           | Notes                              |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| Sessions | Title, Abstract, Level, Category, Duration (min), SubmissionDateTime, SessionLink, PrimarySpeakerName, PrimarySpeakerEmail, PrimarySpeakerJobTitle, PrimarySpeakerBio, CoSpeakerName, CoSpeakerEmail, CoSpeakerJobTitle, CoSpeakerBio | All speaker data embedded in sheet |

## 3. Pre-Import Data Hygiene

| Check                       | Action                                                                      |
| --------------------------- | --------------------------------------------------------------------------- |
| Email formatting            | Lowercase all emails; trim spaces                                           |
| Duration numeric            | Force integer; flag invalid rows                                            |
| Level & Category conformity | Validate against allowed lists; reject non-matching                         |
| Duplicate sessions          | De-dupe by (Campaign + Title + PrimarySpeakerEmail) or custom reference key |
| Co-speaker optionality      | Ensure co-speaker fields NULL if not provided (not empty strings)           |

## 4. Reference Keys

| Entity       | External Id Field                | Construction                                               |
| ------------ | -------------------------------- | ---------------------------------------------------------- |
| Session\_\_c | SessionReference\_\_c (Text 255) | CONCAT(CampaignId,'\|',PrimarySpeakerEmail,'\|',TitleSlug) |

## 5. Transformation (Sheet → CSV)

1. Generate TitleSlug (lowercase, hyphenate, remove punctuation).
2. Normalize whitespace in Abstract/Bio.
3. Convert SubmissionDateTime to ISO (YYYY-MM-DDThh:mm:ssZ) if captured.
4. Ensure picklists exactly match global value sets.

## 6. Import Sequence

| Step | Action                                | Tool                  | Notes                                           |
| ---- | ------------------------------------- | --------------------- | ----------------------------------------------- |
| 1    | Export Sessions → sessions.csv        | Google Sheets         | UTF-8, include all speaker fields               |
| 2    | Upsert Session\_\_c                   | `sf data upsert bulk` | External Id: SessionReference\_\_c              |
| 3    | Verification queries                  | `sf data query`       | Spot check counts & field population            |
| 4    | Initialize evaluator runs (post-load) | Flow / Admin action   | Creates EvaluatorRun\_\_c, sets expected counts |

## 7. Sample Mapping – Session\_\_c

| CSV Column             | Field                       | Required | Notes                       |
| ---------------------- | --------------------------- | -------- | --------------------------- |
| SessionReference       | SessionReference\_\_c       | Yes      | External Id                 |
| CampaignId             | Campaign\_\_c               | Yes      | Provided manually or joined |
| Title                  | Title\_\_c                  | Yes      |                             |
| Abstract               | Abstract\_\_c               | Yes      |                             |
| Level                  | Level\_\_c                  | Yes      | Must match GVS              |
| Category               | Category\_\_c               | Yes      | Must match GVS              |
| Duration               | DurationMinutes\_\_c        | Yes      | Integer                     |
| SubmissionDateTime     | SubmissionDateTime\_\_c     | No       | Optional                    |
| SessionLink            | SessionLink\_\_c            | No       | Sensitive                   |
| PrimarySpeakerName     | PrimarySpeakerName\_\_c     | Yes      |                             |
| PrimarySpeakerEmail    | PrimarySpeakerEmail\_\_c    | Yes      | Lowercase                   |
| PrimarySpeakerJobTitle | PrimarySpeakerJobTitle\_\_c | No       |                             |
| PrimarySpeakerBio      | PrimarySpeakerBio\_\_c      | No       |                             |
| CoSpeakerName          | CoSpeakerName\_\_c          | No       |                             |
| CoSpeakerEmail         | CoSpeakerEmail\_\_c         | No       | Lowercase                   |
| CoSpeakerJobTitle      | CoSpeakerJobTitle\_\_c      | No       |                             |
| CoSpeakerBio           | CoSpeakerBio\_\_c           | No       |                             |

## 8. Post-Import Automation

| Task                          | Mechanism                                                   |
| ----------------------------- | ----------------------------------------------------------- |
| Initialize evaluator runs     | Admin-triggered Flow or Apex batch                          |
| Validate evaluation readiness | Admin checklist (counts align, all required fields present) |
| Contact conversion (optional) | Post-selection Flow or batch to create Contact records      |

## 9. Quality Assurance Checklist

| Item                      | Pass Criterion                                          |
| ------------------------- | ------------------------------------------------------- |
| Session count             | Imported rows = source minus rejected                   |
| Speaker field population  | No blank PrimarySpeakerName or PrimarySpeakerEmail      |
| Picklist integrity        | 0 rejected rows for invalid Level/Category              |
| Aggregation fields zeroed | All sum fields = 0 pre-evaluation                       |
| Co-speaker logic          | If CoSpeakerEmail present, CoSpeakerName also populated |

## 10. Error Handling & Logging

- Use bulk API error CSV to create remediation sheet tab (Errors).
- Optionally import error rows into a lightweight `ImportError__c` custom object for governance tracking.

## 11. Automation Enhancements (Optional)

| Enhancement                                | Benefit                                              |
| ------------------------------------------ | ---------------------------------------------------- |
| Google Apps Script push via REST Composite | Minimizes manual CSV steps                           |
| LWC Import Wizard                          | In-org preview & validation before commit            |
| Data Quality Dashboard                     | Ongoing monitoring of duplicates & missing abstracts |

## 12. Rollback Plan

| Scenario                  | Action                                           |
| ------------------------- | ------------------------------------------------ |
| Corrupted session load    | Delete Sessions by External Id pattern           |
| Wrong campaign assignment | Bulk update Campaign\_\_c via External Id upsert |
| Wrong speaker data        | Re-upsert with corrected speaker fields          |

## 13. Security Considerations

- Restrict who can run bulk upserts (Dedicated integration user / permission set).
- Audit field history on critical objects (Session\_\_c Title/Abstract, speaker email fields).

## 14. Open Questions

| Topic                            | Clarification Needed                             |
| -------------------------------- | ------------------------------------------------ |
| Multi-language abstracts         | Separate rows or translated fields?              |
| Automated email acknowledgements | Send upon session import?                        |
| Contact pre-creation             | Create Contacts during import or post-selection? |

## 15. Quick Command Examples (Illustrative Only)

```bash
# Upsert Sessions (all speaker data embedded)
sf data upsert bulk --sobject Session__c --external-id SessionReference__c --file sessions.csv
```

## 16. Success Criteria

- 100% of valid sessions imported.
- No validation failures on required picklists.
- All sessions tied to an event (Campaign\_\_c populated).
- Primary speaker fields populated for all sessions.
