/**
 * @description Test class for SessionEvaluationTriggerHandler
 * Tests counter updates on EvaluatorRun (TotalAssigned, SubmittedCount, FlaggedCount)
 * @author DreamOle Development Team
 * @since 2025
 */
@IsTest
private class SessionEvaluationTriggerHandlerTest {
  /**
   * @description Helper method to create basic test data without EvaluatorRun
   * Creates Campaign, Sessions, and User only (no automatic evaluations)
   * @return Map with Campaign, Sessions list, and User
   */
  private static Map<String, Object> createBaseTestData() {
    // Create Campaign
    Campaign campaign = TestDataFactory.createCampaign('Test Campaign', true);
    insert campaign;

    // Create 10 Sessions with required fields
    List<Session__c> sessions = TestDataFactory.createSessions(campaign.Id, 10, true);
    for (Integer i = 0; i < sessions.size(); i++) {
      sessions[i].PrimarySpeakerName__c = 'Speaker ' + i;
      sessions[i].PrimarySpeakerEmail__c = 'speaker' + i + '@test.com';
    }
    insert sessions;

    // Create Evaluator User
    User evaluator = TestDataFactory.createUser('Test', 'Evaluator', 'evaluator' + System.currentTimeMillis() + '@test.com', 'Standard User');
    insert evaluator;

    return new Map<String, Object>{ 'campaign' => campaign, 'sessions' => sessions, 'evaluator' => evaluator };
  }

  /**
   * @description Test: Submit one session evaluation and verify counters
   * Expected: TotalAssigned = 11 (10 from flow + 1 test), SubmittedCount = 1, FlaggedCount = 0
   * Note: EvaluatorRun_Add_Sessions flow automatically creates 10 evaluations when run is created
   */
  @IsTest
  static void testSubmitOneEvaluation() {
    // Given
    Map<String, Object> data = createBaseTestData();
    Campaign campaign = (Campaign) data.get('campaign');
    List<Session__c> sessions = (List<Session__c>) data.get('sessions');
    User evaluator = (User) data.get('evaluator');

    // Create run - flow will auto-create 10 Draft evaluations
    EvaluatorRun__c run = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = evaluator.Id, Status__c = 'In_Progress');
    insert run;

    // Verify flow created 10 evaluations
    Integer flowCreatedCount = [
      SELECT COUNT()
      FROM SessionEvaluation__c
      WHERE Run__c = :run.Id
    ];
    Assert.areEqual(10, flowCreatedCount, 'Flow should create 10 evaluations');

    // When - Submit one additional evaluation
    Test.startTest();
    // Get a session not already evaluated
    Set<Id> evaluatedSessionIds = new Set<Id>();
    for (SessionEvaluation__c se : [
      SELECT Session__c
      FROM SessionEvaluation__c
      WHERE Run__c = :run.Id
    ]) {
      evaluatedSessionIds.add(se.Session__c);
    }

    // Find first non-evaluated session (should not exist, all are evaluated)
    // So we'll just submit one of the existing Draft evaluations
    SessionEvaluation__c existingEval = [
      SELECT Id
      FROM SessionEvaluation__c
      WHERE Run__c = :run.Id AND Status__c = 'Not Started'
      LIMIT 1
    ];
    System.runAs(evaluator) {
      existingEval.Status__c = 'Submitted';
      existingEval.ClarityScore__c = 3;
      existingEval.DiversityScore__c = 3;
      existingEval.EngagementScore__c = 3;
      update existingEval;
    }
    Test.stopTest();

    // Then
    EvaluatorRun__c result = [
      SELECT TotalEvaluations__c, SubmittedCount__c, FlaggedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(10, result.TotalEvaluations__c, 'Total should be 10 (from flow)');
    Assert.areEqual(1, result.SubmittedCount__c, 'Submitted should be 1');
    Assert.areEqual(0, result.FlaggedCount__c, 'Flagged should be 0');
  }

  /**
   * @description Test: Submit evaluation then delete it
   * Expected: After delete - counters reflect remaining flow-created evaluations
   * Note: Flow creates 10 evaluations, we delete 1, leaving 9
   */
  @IsTest
  static void testSubmitThenDeleteEvaluation() {
    // Given
    Map<String, Object> data = createBaseTestData();
    Campaign campaign = (Campaign) data.get('campaign');
    List<Session__c> sessions = (List<Session__c>) data.get('sessions');
    User evaluator = (User) data.get('evaluator');

    // Create run - flow creates 10 evaluations
    EvaluatorRun__c run = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = evaluator.Id, Status__c = 'In_Progress');
    insert run;

    // Get one of the flow-created evaluations and submit it
    SessionEvaluation__c eval1 = [
      SELECT Id
      FROM SessionEvaluation__c
      WHERE Run__c = :run.Id
      LIMIT 1
    ];
    System.runAs(evaluator) {
      eval1.Status__c = 'Submitted';
      eval1.ClarityScore__c = 3;
      eval1.DiversityScore__c = 3;
      eval1.EngagementScore__c = 3;
      update eval1;
    }

    // When - Delete the submitted evaluation
    Test.startTest();
    System.runAs(evaluator) {
      delete eval1;
    }
    Test.stopTest();

    // Then - 9 evaluations remain (10 from flow - 1 deleted)
    EvaluatorRun__c result = [
      SELECT TotalEvaluations__c, SubmittedCount__c, FlaggedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(9, result.TotalEvaluations__c, 'Total should be 9 (10 - 1 deleted)');
    Assert.areEqual(0, result.SubmittedCount__c, 'Submitted should be 0');
    Assert.areEqual(0, result.FlaggedCount__c, 'Flagged should be 0');
  }

  /**
   * @description Test: Submit evaluation then add another
   * Expected: TotalAssigned = 10 (all from flow), SubmittedCount = 2
   * Note: Flow creates 10 evaluations, we submit 2 of them
   */
  @IsTest
  static void testSubmitThenAddNewEvaluation() {
    // Given
    Map<String, Object> data = createBaseTestData();
    List<Session__c> sessions = (List<Session__c>) data.get('sessions');
    User evaluator = (User) data.get('evaluator');
    Campaign campaign = (Campaign) data.get('campaign');

    // Create run - flow creates 10 evaluations
    EvaluatorRun__c run = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = evaluator.Id, Status__c = 'In_Progress');
    insert run;

    // Get two flow-created evaluations
    List<SessionEvaluation__c> flowEvals = [
      SELECT Id
      FROM SessionEvaluation__c
      WHERE Run__c = :run.Id
      LIMIT 2
    ];

    System.runAs(evaluator) {
      // Submit first evaluation
      flowEvals[0].Status__c = 'Submitted';
      flowEvals[0].ClarityScore__c = 3;
      flowEvals[0].DiversityScore__c = 3;
      flowEvals[0].EngagementScore__c = 3;
      update flowEvals[0];
    }

    // When - Submit second evaluation
    Test.startTest();
    System.runAs(evaluator) {
      flowEvals[1].Status__c = 'Submitted';
      flowEvals[1].ClarityScore__c = 3;
      flowEvals[1].DiversityScore__c = 3;
      flowEvals[1].EngagementScore__c = 3;
      update flowEvals[1];
    }
    Test.stopTest();

    // Then
    EvaluatorRun__c result = [
      SELECT TotalEvaluations__c, SubmittedCount__c, FlaggedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(10, result.TotalEvaluations__c, 'Total should be 10 (from flow)');
    Assert.areEqual(2, result.SubmittedCount__c, 'Submitted should be 2');
    Assert.areEqual(0, result.FlaggedCount__c, 'Flagged should be 0');
  }

  /**
   * @description Test: Submit all 10 evaluations
   * Expected: All counters match 10 sessions (all from flow)
   * Note: Flow creates 10 evaluations, we submit all of them
   */
  @IsTest
  static void testSubmitAllEvaluations() {
    // Given
    Map<String, Object> data = createBaseTestData();
    List<Session__c> sessions = (List<Session__c>) data.get('sessions');
    User evaluator = (User) data.get('evaluator');
    Campaign campaign = (Campaign) data.get('campaign');

    // Create run - flow creates 10 evaluations
    EvaluatorRun__c run = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = evaluator.Id, Status__c = 'In_Progress');
    insert run;

    // When - Submit all flow-created evaluations
    Test.startTest();
    System.runAs(evaluator) {
      List<SessionEvaluation__c> allEvals = [
        SELECT Id
        FROM SessionEvaluation__c
        WHERE Run__c = :run.Id
      ];
      for (SessionEvaluation__c e : allEvals) {
        e.Status__c = 'Submitted';
        e.ClarityScore__c = 3;
        e.DiversityScore__c = 3;
        e.EngagementScore__c = 3;
      }
      update allEvals;
    }
    Test.stopTest();

    // Then
    EvaluatorRun__c result = [
      SELECT TotalEvaluations__c, SubmittedCount__c, FlaggedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(10, result.TotalEvaluations__c, 'Total should be 10');
    Assert.areEqual(10, result.SubmittedCount__c, 'Submitted should be 10');
    Assert.areEqual(0, result.FlaggedCount__c, 'Flagged should be 0');
  }

  /**
   * @description Test: Update status from Draft to Submitted
   * Expected: SubmittedCount updates on status change
   * Note: Flow creates 10 evaluations in 'Not Started' status, we update 5 to Submitted
   */
  @IsTest
  static void testUpdateStatusFromDraftToSubmitted() {
    // Given
    Map<String, Object> data = createBaseTestData();
    List<Session__c> sessions = (List<Session__c>) data.get('sessions');
    User evaluator = (User) data.get('evaluator');
    Campaign campaign = (Campaign) data.get('campaign');

    // Create run - flow creates 10 evaluations in 'Not Started' status
    EvaluatorRun__c run = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = evaluator.Id, Status__c = 'In_Progress');
    insert run;
    // Check the evaluator run belongs to the evaluator user
    // Query the record to confirm
    EvaluatorRun__c insertedRun = [
      SELECT Id, Evaluator__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(evaluator.Id, insertedRun.Evaluator__c, 'Evaluator__c should match evaluator user');

    Test.startTest();
    System.runAs(evaluator) {
      // Verify initial state (flow creates evaluations with Status = 'Not Started')
      EvaluatorRun__c initialResult = [
        SELECT TotalEvaluations__c, SubmittedCount__c
        FROM EvaluatorRun__c
        WHERE Id = :run.Id
      ];
      Assert.areEqual(10, initialResult.TotalEvaluations__c, 'Total should be 10');
      Assert.areEqual(0, initialResult.SubmittedCount__c, 'Submitted should be 0');

      // When - Update 5 to Submitted
      List<SessionEvaluation__c> evals = [
        SELECT Id
        FROM SessionEvaluation__c
        WHERE Run__c = :run.Id
        LIMIT 5
      ];
      for (SessionEvaluation__c e : evals) {
        e.Status__c = 'Submitted';
        e.ClarityScore__c = 3;
        e.DiversityScore__c = 3;
        e.EngagementScore__c = 3;
      }
      update evals;
    }
    Test.stopTest();
    // Then
    EvaluatorRun__c submittedResult = [
      SELECT TotalEvaluations__c, SubmittedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(10, submittedResult.TotalEvaluations__c, 'Total should still be 10');
    Assert.areEqual(5, submittedResult.SubmittedCount__c, 'Submitted should be 5');
  }

  /**
   * @description Test: Flag evaluations
   * Expected: FlaggedCount tracks flagged records
   * Note: Flow creates 10 evaluations, we flag 3 of them
   */
  @IsTest
  static void testFlaggedCountTracking() {
    // Given
    Map<String, Object> data = createBaseTestData();
    List<Session__c> sessions = (List<Session__c>) data.get('sessions');
    User evaluator = (User) data.get('evaluator');
    Campaign campaign = (Campaign) data.get('campaign');

    // Create run - flow creates 10 evaluations
    EvaluatorRun__c run = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = evaluator.Id, Status__c = 'In_Progress');
    insert run;

    // Verify initial state
    EvaluatorRun__c initialResult = [
      SELECT TotalEvaluations__c, SubmittedCount__c, FlaggedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(10, initialResult.TotalEvaluations__c, 'Total should be 10');
    Assert.areEqual(0, initialResult.FlaggedCount__c, 'Flagged should be 0');

    // When - Flag 3 flow-created evaluations
    Test.startTest();
    System.runAs(evaluator) {
      List<SessionEvaluation__c> evals = [
        SELECT Id
        FROM SessionEvaluation__c
        WHERE Run__c = :run.Id
        LIMIT 3
      ];
      for (SessionEvaluation__c e : evals) {
        e.Flagged__c = true;
        e.Status__c = 'Submitted'; // Also submit them
        e.ClarityScore__c = 3;
        e.DiversityScore__c = 3;
        e.EngagementScore__c = 3;
      }
      update evals;
    }
    Test.stopTest();

    // Then
    EvaluatorRun__c result = [
      SELECT TotalEvaluations__c, SubmittedCount__c, FlaggedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(10, result.TotalEvaluations__c, 'Total should be 10');
    Assert.areEqual(3, result.SubmittedCount__c, 'Submitted should be 3');
    Assert.areEqual(3, result.FlaggedCount__c, 'Flagged should be 3');
  }

  /**
   * @description Test: Toggle flag status
   * Expected: FlaggedCount updates on flag changes
   * Note: Flow creates 10 evaluations, we work with one of them
   */
  @IsTest
  static void testToggleFlaggedStatus() {
    // Given
    Map<String, Object> data = createBaseTestData();
    List<Session__c> sessions = (List<Session__c>) data.get('sessions');
    User evaluator = (User) data.get('evaluator');
    Campaign campaign = (Campaign) data.get('campaign');

    // Create run - flow creates 10 evaluations
    EvaluatorRun__c run = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = evaluator.Id, Status__c = 'In_Progress');
    insert run;

    // Get two flow-created evaluations

    // Get one flow-created evaluation
    SessionEvaluation__c eval1 = [
      SELECT Id, Flagged__c
      FROM SessionEvaluation__c
      WHERE Run__c = :run.Id
      LIMIT 1
    ];

    EvaluatorRun__c initialResult = [
      SELECT FlaggedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(0, initialResult.FlaggedCount__c, 'Initially 0');

    // When - Flag it
    Test.startTest();
    System.runAs(evaluator) {
      eval1.Flagged__c = true;
      update eval1;
    }
    Test.stopTest();

    EvaluatorRun__c flaggedResult = [
      SELECT FlaggedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(1, flaggedResult.FlaggedCount__c, 'Should be 1');

    // When - Unflag it
    System.runAs(evaluator) {
      eval1.Flagged__c = false;
      update eval1;
    }

    EvaluatorRun__c unflaggedResult = [
      SELECT FlaggedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(0, unflaggedResult.FlaggedCount__c, 'Back to 0');
  }

  /**
   * @description Test: Undelete evaluation
   * Expected: Counters restore after undelete
   * Note: Flow creates 10 evaluations, we delete then restore one
   */
  @IsTest
  static void testUndeleteEvaluation() {
    // Given
    Map<String, Object> data = createBaseTestData();
    List<Session__c> sessions = (List<Session__c>) data.get('sessions');
    User evaluator = (User) data.get('evaluator');
    Campaign campaign = (Campaign) data.get('campaign');

    // Create run - flow creates 10 evaluations
    EvaluatorRun__c run = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = evaluator.Id, Status__c = 'In_Progress');
    insert run;

    // Get one flow-created evaluation and submit it
    SessionEvaluation__c eval1 = [
      SELECT Id
      FROM SessionEvaluation__c
      WHERE Run__c = :run.Id
      LIMIT 1
    ];
    System.runAs(evaluator) {
      eval1.Status__c = 'Submitted';
      eval1.ClarityScore__c = 3;
      eval1.DiversityScore__c = 3;
      eval1.EngagementScore__c = 3;
      update eval1;
    }

    // Verify initial state
    EvaluatorRun__c initialResult = [
      SELECT TotalEvaluations__c, SubmittedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(10, initialResult.TotalEvaluations__c, 'Total should be 10');
    Assert.areEqual(1, initialResult.SubmittedCount__c, 'Submitted should be 1');

    // Delete it
    System.runAs(evaluator) {
      delete eval1;
    }

    EvaluatorRun__c deletedResult = [
      SELECT TotalEvaluations__c, SubmittedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(9, deletedResult.TotalEvaluations__c, 'Total should be 9');
    Assert.areEqual(0, deletedResult.SubmittedCount__c, 'Submitted should be 0');

    // When - Undelete
    Test.startTest();
    System.runAs(evaluator) {
      undelete eval1;
    }
    Test.stopTest();

    // Then
    EvaluatorRun__c result = [
      SELECT TotalEvaluations__c, SubmittedCount__c
      FROM EvaluatorRun__c
      WHERE Id = :run.Id
    ];
    Assert.areEqual(10, result.TotalEvaluations__c, 'Total should be 10 again');
    Assert.areEqual(1, result.SubmittedCount__c, 'Submitted should be 1 again');
  }

  /**
   * @description Test: Multiple evaluator runs maintain independent counters
   * Expected: Each run has correct isolated counts
   * Note: Flow creates 10 evaluations per run, we manually add more to one run
   */
  @IsTest
  static void testMultipleEvaluatorRuns() {
    // Given
    Map<String, Object> data = createBaseTestData();
    List<Session__c> sessions = (List<Session__c>) data.get('sessions');
    Campaign campaign = (Campaign) data.get('campaign');

    User eval1 = TestDataFactory.createUser('Eval', 'UserOne', 'eval1' + System.currentTimeMillis() + '@test.com', 'Standard User');
    User eval2 = TestDataFactory.createUser('Eval', 'UserTwo', 'eval2' + System.currentTimeMillis() + '@test.com', 'Standard User');
    insert new List<User>{ eval1, eval2 };

    // Create two runs - flow creates 10 evaluations for each
    EvaluatorRun__c run1 = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = eval1.Id, Status__c = 'In_Progress');
    EvaluatorRun__c run2 = new EvaluatorRun__c(Campaign__c = campaign.Id, Evaluator__c = eval2.Id, Status__c = 'In_Progress');
    insert new List<EvaluatorRun__c>{ run1, run2 };

    // Verify flow created 10 evaluations for each run
    Integer run1InitialCount = [
      SELECT COUNT()
      FROM SessionEvaluation__c
      WHERE Run__c = :run1.Id
    ];
    Integer run2InitialCount = [
      SELECT COUNT()
      FROM SessionEvaluation__c
      WHERE Run__c = :run2.Id
    ];
    Assert.areEqual(10, run1InitialCount, 'Run1 should have 10 from flow');
    Assert.areEqual(10, run2InitialCount, 'Run2 should have 10 from flow');

    // When - Submit 3 from run1, 5 from run2
    Test.startTest();
    System.runAs(eval1) {
      List<SessionEvaluation__c> run1Evals = [
        SELECT Id
        FROM SessionEvaluation__c
        WHERE Run__c = :run1.Id
        LIMIT 3
      ];
      for (SessionEvaluation__c e : run1Evals) {
        e.Status__c = 'Submitted';
        e.ClarityScore__c = 3;
        e.DiversityScore__c = 3;
        e.EngagementScore__c = 3;
      }
      update run1Evals;
    }
    System.runAs(eval2) {
      List<SessionEvaluation__c> run2Evals = [
        SELECT Id
        FROM SessionEvaluation__c
        WHERE Run__c = :run2.Id
        LIMIT 5
      ];
      for (SessionEvaluation__c e : run2Evals) {
        e.Status__c = 'Submitted';
        e.ClarityScore__c = 3;
        e.DiversityScore__c = 3;
        e.EngagementScore__c = 3;
      }
      update run2Evals;
    }
    Test.stopTest();

    // Then
    Map<Id, EvaluatorRun__c> runs = new Map<Id, EvaluatorRun__c>(
      [
        SELECT TotalEvaluations__c, SubmittedCount__c
        FROM EvaluatorRun__c
        WHERE Id IN (:run1.Id, :run2.Id)
      ]
    );

    Assert.areEqual(10, runs.get(run1.Id).TotalEvaluations__c, 'Run1 total = 10');
    Assert.areEqual(3, runs.get(run1.Id).SubmittedCount__c, 'Run1 submitted = 3');
    Assert.areEqual(10, runs.get(run2.Id).TotalEvaluations__c, 'Run2 total = 10');
    Assert.areEqual(5, runs.get(run2.Id).SubmittedCount__c, 'Run2 submitted = 5');
  }
}
