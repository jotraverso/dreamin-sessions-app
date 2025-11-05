# Session Evaluation App – Data Model Specification

## 1. Overview

This document enumerates required custom objects, principal fields, data types, validation, and sensitivity classifications to implement the session evaluation process.

Legend: (S) Sensitive to evaluators, (C) Calculated/Aggregated, (Idx) Consider indexing, (RO) Read-only post finalization.

## 2. Objects & Fields

### 2.1 Session\_\_c

| API Name                      | Label                       | Type                                    | Notes                                                    |
| ----------------------------- | --------------------------- | --------------------------------------- | -------------------------------------------------------- |
| Name                          | Session Name                | Text (Auto / Manual)                    | Typically mirrors Title\_\_c                             |
| Campaign\_\_c                 | Event                       | Lookup(Campaign) (Idx)                  | Parent event                                             |
| Title\_\_c                    | Title                       | Text(255)                               | Required                                                 |
| Abstract\_\_c                 | Abstract                    | Long Text(4000)                         | Required                                                 |
| Level\_\_c                    | Level                       | Picklist (Global: Session_Level_GVS)    | Beginner/Intermediate/Advanced                           |
| Category\_\_c                 | Category                    | Picklist (Global: Session_Category_GVS) | e.g., Development, Marketing                             |
| DurationMinutes\_\_c          | Duration (Min)              | Number(3,0)                             | >0 validation                                            |
| SubmissionDateTime\_\_c       | Submission Date Time        | DateTime                                | Entry timestamp                                          |
| SessionLink\_\_c              | Session Link                | URL                                     | (S) Hide from evaluators                                 |
| Status\_\_c                   | Status                      | Picklist                                | Submitted, In_Review, Finalizing, Selected, Not_Selected |
| PrimarySpeakerName\_\_c       | Primary Speaker Name        | Text(255)                               | (S) Required                                             |
| PrimarySpeakerEmail\_\_c      | Primary Speaker Email       | Email                                   | (S) Required; used for Contact matching                  |
| PrimarySpeakerJobTitle\_\_c   | Primary Speaker Job Title   | Text(120)                               | (S)                                                      |
| PrimarySpeakerBio\_\_c        | Primary Speaker Bio         | Long Text(4000)                         | (S)                                                      |
| PrimarySpeakerContact\_\_c    | Primary Speaker Contact     | Lookup(Contact)                         | (S) Set after conversion for notifications               |
| CoSpeakerName\_\_c            | Co-Speaker Name             | Text(255)                               | (S) Optional                                             |
| CoSpeakerEmail\_\_c           | Co-Speaker Email            | Email                                   | (S) Optional; used for Contact matching                  |
| CoSpeakerJobTitle\_\_c        | Co-Speaker Job Title        | Text(120)                               | (S)                                                      |
| CoSpeakerBio\_\_c             | Co-Speaker Bio              | Long Text(4000)                         | (S)                                                      |
| CoSpeakerContact\_\_c         | Co-Speaker Contact          | Lookup(Contact)                         | (S) Set after conversion for notifications               |
| EvaluationsExpected\_\_c      | Expected Evaluations        | Number(3,0)                             | Set when runs initialized                                |
| EvaluationsSubmitted\_\_c     | Submitted Evaluations       | Number(3,0)                             | Increment via trigger                                    |
| ClaritySum\_\_c               | Clarity Sum                 | Number(6,0)                             | Hidden accumulator                                       |
| DiversitySum\_\_c             | Diversity Sum               | Number(6,0)                             | Hidden accumulator                                       |
| EngagementSum\_\_c            | Engagement Sum              | Number(6,0)                             | Hidden accumulator                                       |
| ClarityAvg\_\_c               | Clarity Avg                 | Number(6,2) (C)                         | Calculated & stored                                      |
| DiversityAvg\_\_c             | Diversity Avg               | Number(5,2) (C)                         | Calculated & stored                                      |
| EngagementAvg\_\_c            | Engagement Avg              | Number(6,2) (C)                         | Calculated & stored                                      |
| FinalScore\_\_c               | Final Score                 | Number(7,2) (C)                         | Sum of averages                                          |
| AllEvaluationsComplete\_\_c   | All Complete                | Formula(Checkbox)                       | `EvaluationsSubmitted__c = EvaluationsExpected__c`       |
| Selected\_\_c                 | Selected                    | Checkbox                                | Organizer action                                         |
| SameSpeakerSelectedEmail\_\_c | Same Speaker Selected Email | Email                                   | (C) Formula showing if primary email matches selected    |

### 2.2 SessionEvaluation\_\_c

| API Name               | Label              | Type                              | Notes                     |
| ---------------------- | ------------------ | --------------------------------- | ------------------------- |
| Session\_\_c           | Session            | Master-Detail(Session\_\_c) (Idx) | Governs ownership cascade |
| Evaluator\_\_c         | Evaluator          | Lookup(User) (Idx)                | Part of uniqueness        |
| Run\_\_c               | Evaluation Run     | Lookup(EvaluatorRun\_\_c)         | Grouping                  |
| ClarityScore\_\_c      | Clarity Score      | Number(2,0)                       | 1–20 validation           |
| DiversityScore\_\_c    | Diversity Score    | Number(2,0)                       | 1–10 validation           |
| EngagementScore\_\_c   | Engagement Score   | Number(2,0)                       | 1–20 validation           |
| TotalScore\_\_c        | Total Score        | Formula(Number)                   | Sum of three scores       |
| Comments\_\_c          | Comments           | Long Text(4000)                   | Optional unless flagged   |
| Flagged\_\_c           | Flagged            | Checkbox                          | Follow-up queue           |
| SkipReason\_\_c        | Skip Reason        | Text(255)                         | Document skip rationale   |
| Status\_\_c            | Status             | Picklist (Draft, Submitted)       | Controls validation       |
| SubmittedDate\_\_c     | Submitted Date     | DateTime                          | Set on submit             |
| FinalizedSnapshot\_\_c | Finalized Snapshot | Checkbox                          | Locks record              |
| IsSkipped\_\_c         | Is Skipped         | Formula(Checkbox)                 | Derived state             |

### 2.3 EvaluatorRun\_\_c

| API Name                | Label              | Type                              | Notes                                                                         |
| ----------------------- | ------------------ | --------------------------------- | ----------------------------------------------------------------------------- |
| Campaign\_\_c           | Event              | Lookup(Campaign) (Idx)            | Context                                                                       |
| Evaluator\_\_c          | Evaluator          | Lookup(User) (Idx)                | Unique per Campaign (enforced via before insert)                              |
| Status\_\_c             | Status             | Picklist (In_Progress, Finalized) |                                                                               |
| Active\_\_c             | Active             | Checkbox (default true)           | Allows temporary exclusion                                                    |
| TargetSessionCount\_\_c | Target Session Cnt | Number(4,0)                       | Optional; total sessions evaluator expected to cover                          |
| StartedAt\_\_c          | Started At         | DateTime                          | Default NOW                                                                   |
| FinalizedAt\_\_c        | Finalized At       | DateTime                          | Set on finalize                                                               |
| TotalAssigned\_\_c      | Total Assigned     | Number(4,0)                       | Reserved if partial distribution implemented                                  |
| SubmittedCount\_\_c     | Submitted Count    | Number(4,0)                       | Incremented                                                                   |
| FlaggedCount\_\_c       | Flagged Count      | Number(4,0)                       | Maintained by trigger                                                         |
| PercentComplete\_\_c    | % Complete         | Formula(Percent)                  | (`SubmittedCount__c / CASE(TargetSessionCount__c,0,1,TargetSessionCount__c)`) |
| AllSubmitted\_\_c       | All Submitted      | Formula(Checkbox)                 | Guard finalize action                                                         |
| FinalizationToken\_\_c  | Finalization Token | Text(32)                          | Idempotency                                                                   |

### 2.4 (Removed) CampaignEvaluatorAssignment\_\_c and Speaker\_\_c

Replaced by single EvaluatorRun\_\_c record per Campaign + Evaluator. Fields for active state and target counts migrated into EvaluatorRun. Historical assignment features (e.g., locking) can be simulated by setting `Active__c = false` or storing a timestamp on the Campaign when runs become immutable.

## 3. Global Value Sets

| Name                          | Values                                                                                      | Purpose                  |
| ----------------------------- | ------------------------------------------------------------------------------------------- | ------------------------ |
| Session_Level_GVS             | Beginner; Intermediate; Advanced                                                            | Normalized session level |
| Session_Category_GVS          | Development; Marketing; Sales; Architecture; Admin; Analytics; Integration; Security; Other | Flexible taxonomy        |
| Session_Status_GVS (optional) | Submitted; In_Review; Finalizing; Selected; Not_Selected                                    | Lifecycle control        |

## 4. Validation Rules (Representative)

| Object                 | Rule Purpose             | Logic Sketch                                                               |
| ---------------------- | ------------------------ | -------------------------------------------------------------------------- |
| SessionEvaluation\_\_c | Clarity range            | `OR(ClarityScore__c<1, ClarityScore__c>20)`                                |
| SessionEvaluation\_\_c | Diversity range          | `OR(DiversityScore__c<1, DiversityScore__c>10)`                            |
| SessionEvaluation\_\_c | Engagement range         | `OR(EngagementScore__c<1, EngagementScore__c>20)`                          |
| SessionEvaluation\_\_c | Require scores on submit | `AND(ISPICKVAL(Status__c,"Submitted"), OR(ISBLANK(ClarityScore__c), ...))` |
| SessionEvaluation\_\_c | Lock after finalize      | `FinalizedSnapshot__c = TRUE` (Error on edit)                              |
| Session\_\_c           | Duration positive        | `DurationMinutes__c <= 0`                                                  |

## 5. Indexing Recommendations

- Add selective indexes (support case) for: `Session__c.Campaign__c`, `Session__c.PrimarySpeakerEmail__c` (for duplicate speaker detection), `SessionEvaluation__c.Session__c`, `SessionEvaluation__c.Evaluator__c`, `EvaluatorRun__c.Campaign__c + Evaluator__c` (uniqueness per Campaign+Evaluator removes need for assignment object).

## 6. Aggregation Fields Strategy

- Increment sums (ClaritySum\_\_c, etc.) in AFTER INSERT/UPDATE when Status transitions to Submitted (ignore Draft changes).
- Expected evaluations per Session (full coverage model) = COUNT of active EvaluatorRun**c for its Campaign. If partial coverage introduced later, use per-session mapping or `TotalAssigned**c` on each run.
- Recompute averages only when session completes OR via scheduled reconciliation.

## 7. Security Classification

| Classification       | Definition               | Examples                                                                           |
| -------------------- | ------------------------ | ---------------------------------------------------------------------------------- |
| Public to Evaluators | Safe for scoring context | Title\_\_c, Abstract\_\_c, Level\_\_c                                              |
| Restricted (PII)     | Hide from evaluators     | All speaker fields (Name, Email, Bio, JobTitle), Contact lookups, SessionLink\_\_c |
| Internal Metrics     | System-managed           | Sums, Averages, FinalScore\_\_c                                                    |

## 8. Future Expansion Placeholders

| Area                        | Approach                                                        |
| --------------------------- | --------------------------------------------------------------- |
| Additional Score Dimensions | Add fields + metadata-driven range table                        |
| Internationalization        | Add Language\_\_c on Session & localized abstracts              |
| Versioned Submissions       | Introduce SessionVersion\_\_c child object                      |
| Automated Contact Sync      | Flow/Apex triggered on selection to create/link Contact records |

## 9. Open Issues / To Decide

| Topic                         | Question                                                       |
| ----------------------------- | -------------------------------------------------------------- |
| Skipped logic                 | Count skipped sessions toward completion?                      |
| Multi-phase evaluation        | Need Phase dimension? (Could add Phase\_\_c on EvaluatorRun)   |
| Contact conversion automation | Automatic on selection OR manual admin action via button/Flow? |
| Duplicate Contact handling    | Match by email before creating; upsert vs create-only?         |
| Partial distribution          | If evaluators don't rate all sessions, need mapping object?    |
