/**
 * @description Trigger for SessionEvaluation__c object using TriggerHandler framework
 * Handles after insert, update, delete, and undelete operations for evaluation aggregation and counter rollups
 * @see SessionEvaluationTriggerHandler
 */
trigger SessionEvaluationTrigger on SessionEvaluation__c(
  after insert,
  after update,
  after delete,
  after undelete
) {
  new SessionEvaluationTriggerHandler().run();
}
