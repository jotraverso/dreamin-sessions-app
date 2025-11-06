/**
 * @description Trigger for SessionEvaluation__c object using TriggerHandler framework
 * Handles after insert and after update operations for evaluation aggregation
 * @see SessionEvaluationTriggerHandler
 */
trigger SessionEvaluationTrigger on SessionEvaluation__c(
  after insert,
  after update
) {
  new SessionEvaluationTriggerHandler().run();
}
