@IsTest
private class EvaluatorRunFlowTest {
  @IsTest
  static void testEvaluatorRunCreatesSessionEvaluations() {
    // Arrange: create campaign, sessions, evaluator user
    Campaign c = TestDataFactory.createCampaign('Flow Test Campaign', true);
    insert c;

    List<Session__c> sessions = TestDataFactory.createSessions(c.Id, 3, false);
    insert sessions;

    // Create a user to act as evaluator/owner
    User evalUser = TestDataFactory.createUser('Eval', 'User', 'evaluser_flowtest@example.com', 'Standard User');
    insert evalUser;

    // Act: create EvaluatorRun (the flow EvaluatorRun Add Sessions is a record-triggered flow on EvaluatorRun__c create)
    EvaluatorRun__c run = TestDataFactory.createEvaluatorRun(c.Id, evalUser.Id, 10);
    insert run;

    // Because flows run after commit, query for created SessionEvaluation records
    List<SessionEvaluation__c> evaluations = [
      SELECT Id, Session__c, Evaluator__c, Run__c
      FROM SessionEvaluation__c
      WHERE Run__c = :run.Id
    ];

    // Assert: one SessionEvaluation per Session exists and evaluator/owner match
    System.assertEquals(3, evaluations.size(), 'Expected one SessionEvaluation per Session in the campaign');

    Map<Id, SessionEvaluation__c> bySession = new Map<Id, SessionEvaluation__c>();
    for (SessionEvaluation__c se : evaluations) {
      bySession.put(se.Session__c, se);
      System.assertEquals(evalUser.Id, se.Evaluator__c, 'SessionEvaluation Evaluator should match EvaluatorRun Evaluator');
      System.assertEquals(run.Id, se.Run__c, 'SessionEvaluation Run lookup should point to the created EvaluatorRun');
    }

    // Verify that each session has a matching evaluation
    for (Session__c s : sessions) {
      System.assert(bySession.containsKey(s.Id), 'Expected SessionEvaluation for Session ' + s.Id);
    }

    // Verify EvaluatorRun counters: TotalEvaluations__c should equal 3
    EvaluatorRun__c runReload = [
      SELECT Id, TotalEvaluations__c, SubmittedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
      LIMIT 1
    ];

    System.assertEquals(
      3,
      Integer.valueOf(runReload.TotalEvaluations__c),
      'EvaluatorRun TotalEvaluations__c should equal number of created SessionEvaluations'
    );

    // SubmittedCount should remain 0 since evaluations are created as Not Started or Draft
    System.assertEquals(0, Integer.valueOf(runReload.SubmittedCount__c), 'SubmittedCount__c should be 0 immediately after creation');
  }
}
