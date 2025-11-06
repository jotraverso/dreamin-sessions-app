/**
 * @description Trigger Handler for SessionEvaluation__c object
 * Handles aggregation and counter updates when evaluations are submitted
 * @author DreamOle Development Team
 * @since 2025
 */
public with sharing class SessionEvaluationTriggerHandler extends TriggerHandler {
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
  }

  /**
   * @description After update handler - processes status changes to Submitted
   */
  public override void afterUpdate() {
    handleEvaluationSubmission(this.newRecords, this.oldRecordsMap);
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
}
