/**
 * @description Trigger Handler for SessionEvaluation__c object
 * Handles aggregation and counter updates when evaluations are submitted
 * @author DreamOle Development Team
 * @since 2025
 */
public without sharing class SessionEvaluationTriggerHandler extends TriggerHandler {
  private List<SessionEvaluation__c> newRecords;
  private List<SessionEvaluation__c> oldRecords;
  private Map<Id, SessionEvaluation__c> newRecordsMap;
  private Map<Id, SessionEvaluation__c> oldRecordsMap;

  /**
   * @description Constructor that casts trigger collections for type safety
   */
  public SessionEvaluationTriggerHandler() {
    super('SessionEvaluationTriggerHandler');
    this.newRecords = (List<SessionEvaluation__c>) Trigger.new;
    this.oldRecords = (List<SessionEvaluation__c>) Trigger.old;
    this.newRecordsMap = (Map<Id, SessionEvaluation__c>) Trigger.newMap;
    this.oldRecordsMap = (Map<Id, SessionEvaluation__c>) Trigger.oldMap;
  }

  /**
   * @description After insert handler - processes newly submitted evaluations
   */
  public override void afterInsert() {
    handleEvaluationSubmission(this.newRecords, null);
    updateEvaluatorRunCountsOnChange(this.newRecords, null);
  }

  /**
   * @description After update handler - processes status changes to Submitted
   */
  public override void afterUpdate() {
    handleEvaluationSubmission(this.newRecords, this.oldRecordsMap);
    updateEvaluatorRunCountsOnChange(this.newRecords, this.oldRecordsMap);
  }

  /**
   * @description After delete handler - updates counts when evaluations are deleted
   */
  public override void afterDelete() {
    updateEvaluatorRunCountsOnChange(this.oldRecords, null);
  }

  /**
   * @description After undelete handler - updates counts when evaluations are restored
   */
  public override void afterUndelete() {
    updateEvaluatorRunCountsOnChange(this.newRecords, null);
  }

  /**
   * @description Handles evaluation submission by triggering aggregation
   * @param newEvaluations List of new or updated evaluations
   * @param oldEvaluationsMap Map of old evaluation records (null for insert)
   */
  private void handleEvaluationSubmission(
    List<SessionEvaluation__c> newEvaluations,
    Map<Id, SessionEvaluation__c> oldEvaluationsMap
  ) {
    Set<Id> sessionsToAggregate = new Set<Id>();
    Set<Id> runsToUpdate = new Set<Id>();

    for (SessionEvaluation__c evaluation : newEvaluations) {
      // Only process if status is now Submitted
      if (evaluation.Status__c == 'Submitted') {
        // Check if this is a new submission (insert or status change)
        Boolean isNewSubmission =
          (oldEvaluationsMap == null) ||
          (oldEvaluationsMap.get(evaluation.Id).Status__c != 'Submitted');

        if (isNewSubmission && evaluation.Session__c != null) {
          sessionsToAggregate.add(evaluation.Session__c);

          if (evaluation.Run__c != null) {
            runsToUpdate.add(evaluation.Run__c);
          }
        }
      }
    }

    // Trigger aggregation asynchronously to avoid governor limits
    if (!sessionsToAggregate.isEmpty()) {
      SessionAggregationService.aggregateSessionsAsync(sessionsToAggregate);
    }

    // Update evaluator run counters
    if (!runsToUpdate.isEmpty()) {
      updateEvaluatorRunCounters(runsToUpdate);
    }
  }

  /**
   * @description Updates the evaluated counter on EvaluatorRun records
   * @param runIds Set of EvaluatorRun IDs to update
   */
  private void updateEvaluatorRunCounters(Set<Id> runIds) {
    Map<Id, Integer> runCounts = new Map<Id, Integer>();

    // Query current counts
    for (AggregateResult ar : [
      SELECT Run__c, COUNT(Id) evalCount
      FROM SessionEvaluation__c
      WHERE Run__c IN :runIds AND Status__c = 'Submitted'
      GROUP BY Run__c
    ]) {
      runCounts.put((Id) ar.get('Run__c'), (Integer) ar.get('evalCount'));
    }

    // Update runs
    List<EvaluatorRun__c> runsToUpdate = new List<EvaluatorRun__c>();
    for (Id runId : runIds) {
      Integer count = runCounts.containsKey(runId) ? runCounts.get(runId) : 0;
      runsToUpdate.add(
        new EvaluatorRun__c(Id = runId, SubmittedCount__c = count)
      );
    }

    if (!runsToUpdate.isEmpty()) {
      update runsToUpdate;
    }
  }

  /**
   * @description Updates all counters on EvaluatorRun when evaluations change
   * Maintains TotalAssigned, SubmittedCount, and FlaggedCount
   * @param evaluations List of evaluations that changed
   * @param oldEvaluationsMap Map of old evaluation records (null for insert/undelete)
   */
  private void updateEvaluatorRunCountsOnChange(
    List<SessionEvaluation__c> evaluations,
    Map<Id, SessionEvaluation__c> oldEvaluationsMap
  ) {
    Set<Id> runIds = collectAffectedRunIds(evaluations, oldEvaluationsMap);

    if (runIds.isEmpty()) {
      return;
    }

    Map<Id, EvaluatorRun__c> runsToUpdate = calculateRunCounts(runIds);

    if (!runsToUpdate.isEmpty()) {
      update runsToUpdate.values();
    }
  }

  /**
   * @description Collects all EvaluatorRun IDs affected by evaluation changes
   * @param evaluations List of evaluations that changed
   * @param oldEvaluationsMap Map of old evaluation records
   * @return Set of affected run IDs
   */
  private Set<Id> collectAffectedRunIds(
    List<SessionEvaluation__c> evaluations,
    Map<Id, SessionEvaluation__c> oldEvaluationsMap
  ) {
    Set<Id> runIds = new Set<Id>();

    // Collect current run IDs
    for (SessionEvaluation__c evaluation : evaluations) {
      if (evaluation.Run__c != null) {
        runIds.add(evaluation.Run__c);
      }
    }

    // Include previous run IDs if evaluations were reparented
    if (oldEvaluationsMap != null) {
      for (SessionEvaluation__c evaluation : evaluations) {
        SessionEvaluation__c oldEval = oldEvaluationsMap.get(evaluation.Id);
        if (
          oldEval != null &&
          oldEval.Run__c != null &&
          oldEval.Run__c != evaluation.Run__c
        ) {
          runIds.add(oldEval.Run__c);
        }
      }
    }

    return runIds;
  }

  /**
   * @description Calculates all count fields for the given runs
   * @param runIds Set of EvaluatorRun IDs to calculate counts for
   * @return Map of EvaluatorRun records with updated counts
   */
  private Map<Id, EvaluatorRun__c> calculateRunCounts(Set<Id> runIds) {
    Map<Id, EvaluatorRun__c> runsToUpdate = initializeRunCounts(runIds);

    aggregateTotalAssigned(runIds, runsToUpdate);
    aggregateSubmittedCount(runIds, runsToUpdate);
    aggregateFlaggedCount(runIds, runsToUpdate);

    return runsToUpdate;
  }

  /**
   * @description Initializes EvaluatorRun records with zero counts
   * @param runIds Set of run IDs to initialize
   * @return Map of initialized runs
   */
  private Map<Id, EvaluatorRun__c> initializeRunCounts(Set<Id> runIds) {
    Map<Id, EvaluatorRun__c> runsMap = new Map<Id, EvaluatorRun__c>();

    for (Id runId : runIds) {
      runsMap.put(
        runId,
        new EvaluatorRun__c(
          Id = runId,
          TotalAssigned__c = 0,
          SubmittedCount__c = 0,
          FlaggedCount__c = 0
        )
      );
    }

    return runsMap;
  }

  /**
   * @description Aggregates total assigned count for runs
   * @param runIds Set of run IDs
   * @param runsMap Map to update with counts
   */
  private void aggregateTotalAssigned(
    Set<Id> runIds,
    Map<Id, EvaluatorRun__c> runsMap
  ) {
    for (AggregateResult ar : [
      SELECT Run__c, COUNT(Id) totalCount
      FROM SessionEvaluation__c
      WHERE Run__c IN :runIds
      GROUP BY Run__c
    ]) {
      Id runId = (Id) ar.get('Run__c');
      runsMap.get(runId).TotalAssigned__c = (Integer) ar.get('totalCount');
    }
  }

  /**
   * @description Aggregates submitted count for runs
   * @param runIds Set of run IDs
   * @param runsMap Map to update with counts
   */
  private void aggregateSubmittedCount(
    Set<Id> runIds,
    Map<Id, EvaluatorRun__c> runsMap
  ) {
    for (AggregateResult ar : [
      SELECT Run__c, COUNT(Id) submittedCount
      FROM SessionEvaluation__c
      WHERE Run__c IN :runIds AND Status__c = 'Submitted'
      GROUP BY Run__c
    ]) {
      Id runId = (Id) ar.get('Run__c');
      runsMap.get(runId).SubmittedCount__c = (Integer) ar.get('submittedCount');
    }
  }

  /**
   * @description Aggregates flagged count for runs
   * @param runIds Set of run IDs
   * @param runsMap Map to update with counts
   */
  private void aggregateFlaggedCount(
    Set<Id> runIds,
    Map<Id, EvaluatorRun__c> runsMap
  ) {
    for (AggregateResult ar : [
      SELECT Run__c, COUNT(Id) flaggedCount
      FROM SessionEvaluation__c
      WHERE Run__c IN :runIds AND Flagged__c = TRUE
      GROUP BY Run__c
    ]) {
      Id runId = (Id) ar.get('Run__c');
      runsMap.get(runId).FlaggedCount__c = (Integer) ar.get('flaggedCount');
    }
  }
}
