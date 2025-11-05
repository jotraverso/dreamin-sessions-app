# Session Evaluation App – Application & UX Specification

## 1. Lightning App Overview

**App Name:** Session Evaluation Console
Provides two personas: Evaluator & Organizer. Tailored LWCs deliver queue-like evaluation flow and post-aggregation selection workspace.

## 2. Navigation Items

| Order | Item                | Type                             | Persona         |
| ----- | ------------------- | -------------------------------- | --------------- |
| 1     | Evaluate Sessions   | LWC Tab (evalWorkbenchContainer) | Evaluator       |
| 2     | Flagged Sessions    | LWC Tab (evalFlaggedList)        | Evaluator       |
| 3     | My Summary          | LWC Tab (evalSummaryReview)      | Evaluator       |
| 4     | Organizer Dashboard | LWC Tab (organizerSessionList)   | Organizer       |
| 5     | Sessions            | Object Tab                       | Organizer/Admin |
| 6     | Contacts            | Object Tab                       | Organizer/Admin |
| 7     | Evaluations         | Object Tab                       | Admin           |

## 3. Evaluator Workflow Components

| Component                 | Purpose                                                      | Key Interactions                            |
| ------------------------- | ------------------------------------------------------------ | ------------------------------------------- |
| evalWorkbenchContainer    | Orchestrates next-session fetch, houses detail & rating form | Calls Apex `getNextSessionForEvaluator`     |
| sessionEvalDetail         | Displays allowed session info (no PII)                       | Receives session DTO sans restricted fields |
| sessionRatingForm         | Capture scores, live validation & draft autosave             | Emits saveDraft / submit events             |
| sessionQueuePanel         | Progress metrics (remaining, flagged, submitted)             | Poll or subscribe via wired Apex            |
| evalFlaggedList           | Manage flagged sessions & revisit before finalization        | Unflag / submit actions                     |
| evalSummaryReview         | Pre-finalization summary & status table                      | Triggers finalize modal                     |
| finalizeConfirmationModal | Confirms finalize; checks Custom Permission                  | Defensive double-submit prevention          |

## 4. Organizer Workflow Components

| Component                      | Purpose                                                    | Key Features                                               |
| ------------------------------ | ---------------------------------------------------------- | ---------------------------------------------------------- |
| organizerSessionList           | Tabular aggregated view with filters & mass actions        | Lightning datatable + inline selection toggles             |
| organizerSessionDetail         | Full drill-down: speaker info + all evaluations            | Conditional sections by persona; shows speaker fields      |
| sessionSelectionPanel          | Bulk mark Selected / Not Selected with conflict indicators | Optimistic UI + rollback on failure; duplicate email check |
| speakerConflictIndicator       | Badge if same email tied to another selected session       | Server-computed property via SOQL                          |
| evaluationDrillDown            | Expand/collapse list of individual evaluations             | Sorting, score distribution mini-chart                     |
| massFinalizeMonitor (optional) | Displays progress of batch final aggregation jobs          | Polling on Platform Event                                  |

## 5. Record Types & Layouts

| Object                 | Record Type      | Purpose                                       | Layout Notes                                                             |
| ---------------------- | ---------------- | --------------------------------------------- | ------------------------------------------------------------------------ |
| Session\_\_c           | Default (Single) | Uniform submission intake                     | Two-column layout; speaker fields in section; separate Aggregation panel |
| SessionEvaluation\_\_c | Default          | Draft vs Submitted controlled by Status field | Hide system fields from evaluators                                       |
| Contact                | Default          | Speaker contacts for notifications            | Standard Contact layout                                                  |

(Additional record types not required at MVP.)

## 6. Permission Sets (High-Level)

| Permission Set            | Scope                                                      | Notes                                           |
| ------------------------- | ---------------------------------------------------------- | ----------------------------------------------- |
| SessEval_Session_Read     | Read session non-PII fields                                | No access to speaker fields or SessionLink\_\_c |
| SessEval_Evaluation_Write | CRUD (own) evaluations; view run progress                  | OWD Private ensures privacy                     |
| SessEval_Finalize_Execute | Custom Permission: CanFinalizeEvaluations                  | Gate finalize button                            |
| SessOrg_Organizer_Full    | Full access to sessions, read evaluations, manage Contacts | Can edit selection fields, convert to Contacts  |
| SessAdmin_Admin           | Admin superset                                             | Manage runs & aggregation                       |

### Field-Level Security Enforcement

- Deny PII fields to evaluator sets (Session.PrimarySpeakerName\_\_c, PrimarySpeakerEmail\_\_c, PrimarySpeakerBio\_\_c, PrimarySpeakerJobTitle\_\_c, CoSpeaker\* fields, SessionLink\_\_c, Contact lookups).
- Provide read to organizers, full to admin.

## 7. Apex Service Layer (Logical Contracts)

| Class                     | Method                                         | Input         | Output     | Notes                                                       |
| ------------------------- | ---------------------------------------------- | ------------- | ---------- | ----------------------------------------------------------- |
| SessionEvaluationService  | getNextSessionForEvaluator(campaignId, userId) | IDs           | SessionDTO | Excludes PII                                                |
| SessionEvaluationService  | saveDraft(dto)                                 | EvaluationDTO | Id         | Upserts Draft                                               |
| SessionEvaluationService  | submitEvaluation(evaluationId)                 | Id            | Void       | Validates ranges + transitions                              |
| SessionEvaluationService  | flagSession(evaluationId, reason)              | Id+Text       | Void       | Sets Flagged\_\_c                                           |
| SessionEvaluationService  | finalizeRun(runId)                             | Id            | Void       | Locks remaining drafts & triggers aggregation check         |
| SessionAggregationService | aggregateSession(sessionId)                    | Id            | Void       | Computes sums → averages                                    |
| SessionAggregationService | aggregateCampaign(campaignId)                  | Id            | Void       | Bulk finalize scores                                        |
| RunInitializationService  | initializeRuns(campaignId)                     | Id            | Void       | Creates EvaluatorRun records (full coverage)                |
| RunInitializationService  | recalcExpectedCounts(campaignId)               | Id            | Void       | Recomputes expected evaluations per session                 |
| ContactConversionService  | convertSelectedSessions(campaignId)            | Id            | Integer    | Creates/links Contacts for selected sessions; returns count |
| ContactConversionService  | convertSession(sessionId)                      | Id            | Void       | Single session Contact conversion with email matching       |

### DTO Shielding

- DTO excludes sensitive fields automatically based on running user context.

## 8. UI State & Navigation Rules

| Scenario                          | Behavior                                               |
| --------------------------------- | ------------------------------------------------------ |
| No remaining unevaluated sessions | Show completion panel with link to Summary             |
| Attempt finalize with drafts      | Modal lists incomplete; block finalize                 |
| Flagged revisit mode              | Workbench cycles only flagged until resolved/unflagged |
| Offline/Draft autosave failure    | Local storage queue + retry banner                     |

## 9. Aggregation Trigger Points

| Event                        | Action                                                                 |
| ---------------------------- | ---------------------------------------------------------------------- |
| Evaluation submitted         | Increment session sums & counts, conditional aggregate if all complete |
| All evaluator runs finalized | Campaign-wide re-aggregation for consistency                           |
| Session selection changed    | Recompute conflict indicators asynchronously                           |

## 10. Error & Concurrency Handling

| Case                                    | Strategy                                                              |
| --------------------------------------- | --------------------------------------------------------------------- |
| Simultaneous submission same evaluation | Row lock via FOR UPDATE; second attempt gracefully refreshes          |
| Lost network mid-submit                 | Client retries with idempotency key in DTO                            |
| Aggregation partial failure             | Queueable logs error + surfaces toast via Platform Event subscription |

## 11. Accessibility & UX Principles

- Keyboard navigable scoring inputs (arrow key increments with bounds).
- Distinct color semantics for Flagged vs Submitted vs Draft.
- Lazy load evaluation drill-down data.

## 12. Telemetry (Optional)

Custom object or Event Monitoring to capture average time per evaluation and abandonment points (draft never submitted > X hours).

## 13. Future Enhancements (Parking Lot)

| Idea                                              | Benefit                         |
| ------------------------------------------------- | ------------------------------- |
| Inline sentiment analysis on comments             | Identify polarizing sessions    |
| Bulk CSV export from organizer list               | External adjudication processes |
| Real-time collaborative organizer selection board | Reduce decision meeting time    |
