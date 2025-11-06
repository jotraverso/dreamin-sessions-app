/**
 * @description Service class for aggregating session scores
 * Handles calculation of averages and final scores
 */
public with sharing class SessionAggregationService {
  /**
   * @description Aggregate scores for a single session
   * @param sessionId Session record ID
   */
  @AuraEnabled
  public static void aggregateSession(Id sessionId) {
    Session__c session = [
      SELECT
        Id,
        ClaritySum__c,
        DiversitySum__c,
        EngagementSum__c,
        EvaluationsSubmitted__c,
        EvaluationsExpected__c
      FROM Session__c
      WHERE Id = :sessionId
      FOR UPDATE
    ];

    // Query all submitted evaluations
    List<AggregateResult> results = [
      SELECT
        SUM(ClarityScore__c) claritySum,
        SUM(DiversityScore__c) diversitySum,
        SUM(EngagementScore__c) engagementSum,
        COUNT(Id) evalCount
      FROM SessionEvaluation__c
      WHERE Session__c = :sessionId AND Status__c = 'Submitted'
    ];

    if (results.isEmpty() || results[0].get('evalCount') == 0) {
      return;
    }

    AggregateResult aggr = results[0];
    Integer evalCount = (Integer) aggr.get('evalCount');

    session.ClaritySum__c = (Decimal) aggr.get('claritySum');
    session.DiversitySum__c = (Decimal) aggr.get('diversitySum');
    session.EngagementSum__c = (Decimal) aggr.get('engagementSum');
    session.EvaluationsSubmitted__c = evalCount;

    // Calculate averages
    if (evalCount > 0) {
      session.ClarityAvg__c = session.ClaritySum__c / evalCount;
      session.DiversityAvg__c = session.DiversitySum__c / evalCount;
      session.EngagementAvg__c = session.EngagementSum__c / evalCount;
      session.FinalScore__c =
        session.ClarityAvg__c +
        session.DiversityAvg__c +
        session.EngagementAvg__c;
    }

    update session;
  }

  /**
   * @description Asynchronously aggregates multiple sessions
   * @param sessionIds Set of Session IDs to aggregate
   */
  @future
  public static void aggregateSessionsAsync(Set<Id> sessionIds) {
    List<Session__c> sessions = [
      SELECT Id
      FROM Session__c
      WHERE Id IN :sessionIds
    ];
    for (Session__c session : sessions) {
      aggregateSession(session.Id);
    }
  } /**
   * @description Batch aggregation for large campaigns (called from batch class)
   * @param sessionIds List of session IDs to aggregate
   */
  public static void batchAggregate(List<Id> sessionIds) {
    for (Id sessionId : sessionIds) {
      try {
        aggregateSession(sessionId);
      } catch (Exception e) {
        System.debug(
          'Error aggregating session ' + sessionId + ': ' + e.getMessage()
        );
      }
    }
  }

  /**
   * @description Recalculate expected evaluation counts for all sessions in campaign
   * @param campaignId Campaign ID
   */
  @AuraEnabled
  public static void recalculateExpectedCounts(Id campaignId) {
    // Count active evaluator runs
    Integer activeEvaluatorCount = [
      SELECT COUNT()
      FROM EvaluatorRun__c
      WHERE Campaign__c = :campaignId AND Active__c = TRUE
    ];

    // Update all sessions
    List<Session__c> sessions = [
      SELECT Id, EvaluationsExpected__c
      FROM Session__c
      WHERE Campaign__c = :campaignId
    ];

    for (Session__c session : sessions) {
      session.EvaluationsExpected__c = activeEvaluatorCount;
    }

    update sessions;
  }
}
