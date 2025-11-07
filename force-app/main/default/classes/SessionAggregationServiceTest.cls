/**
 * @description Test class for SessionAggregationService
 * Covers aggregation of single session, async aggregation and recalculation
 * of expected counts for sessions in a campaign.
 */
@IsTest
private class SessionAggregationServiceTest {
  @IsTest
  static void testAggregateSession() {
    // Given: campaign, session and submitted evaluations
    Campaign camp = TestDataFactory.createCampaign('Agg Camp', true);
    insert camp;

    Session__c sess = TestDataFactory.createSessionWithSpeaker(
      camp.Id,
      'Agg Session',
      'Speaker A',
      'speakerA@test.com',
      true
    );
    insert sess;

    User evaluator = TestDataFactory.createUser(
      'Eval',
      'OneUser',
      'eval.one' + System.currentTimeMillis() + '@test.com',
      'Standard User'
    );
    insert evaluator;

    // Create 3 submitted evaluations with known scores
    List<SessionEvaluation__c> evals = new List<SessionEvaluation__c>();
    evals.add(
      TestDataFactory.createSessionEvaluationWithScores(
        sess.Id,
        evaluator.Id,
        null,
        4,
        3,
        5,
        'Submitted'
      )
    );
    evals.add(
      TestDataFactory.createSessionEvaluationWithScores(
        sess.Id,
        evaluator.Id,
        null,
        5,
        4,
        2,
        'Submitted'
      )
    );
    evals.add(
      TestDataFactory.createSessionEvaluationWithScores(
        sess.Id,
        evaluator.Id,
        null,
        3,
        5,
        4,
        'Submitted'
      )
    );
    insert evals;

    // When
    Test.startTest();
    SessionAggregationService.aggregateSession(sess.Id);
    Test.stopTest();

    // Then - verify sums, counts and averages
    Session__c result = [
      SELECT
        Id,
        ClaritySum__c,
        DiversitySum__c,
        EngagementSum__c,
        EvaluationsSubmitted__c,
        ClarityAvg__c,
        DiversityAvg__c,
        EngagementAvg__c,
        FinalScore__c
      FROM Session__c
      WHERE Id = :sess.Id
    ];

    Integer expectedCount = 3;
    Integer expectedClaritySum = 4 + 5 + 3;
    Integer expectedDiversitySum = 3 + 4 + 5;
    Integer expectedEngagementSum = 5 + 2 + 4;

    System.assertEquals(
      expectedCount,
      result.EvaluationsSubmitted__c,
      'Submitted count'
    );
    System.assertEquals(
      expectedClaritySum,
      result.ClaritySum__c.intValue(),
      'Clarity sum'
    );
    System.assertEquals(
      expectedDiversitySum,
      result.DiversitySum__c.intValue(),
      'Diversity sum'
    );
    System.assertEquals(
      expectedEngagementSum,
      result.EngagementSum__c.intValue(),
      'Engagement sum'
    );

    // Averages and final score
    Decimal expectedClarityAvg = (Decimal) expectedClaritySum / expectedCount;
    Decimal expectedDiversityAvg =
      (Decimal) expectedDiversitySum / expectedCount;
    Decimal expectedEngagementAvg =
      (Decimal) expectedEngagementSum / expectedCount;
    Decimal expectedFinal =
      expectedClarityAvg +
      expectedDiversityAvg +
      expectedEngagementAvg;

    // Use a small tolerance for decimal comparisons
    Decimal tol = 0.0001;
    System.assert(
      Math.abs(result.ClarityAvg__c - expectedClarityAvg) < tol,
      'Clarity avg'
    );
    System.assert(
      Math.abs(result.DiversityAvg__c - expectedDiversityAvg) < tol,
      'Diversity avg'
    );
    System.assert(
      Math.abs(result.EngagementAvg__c - expectedEngagementAvg) < tol,
      'Engagement avg'
    );
    System.assert(
      Math.abs(result.FinalScore__c - expectedFinal) < tol,
      'Final score'
    );
  }

  @IsTest
  static void testAggregateSessionsAsync() {
    // Given: campaign and two sessions each with submitted evaluations
    Campaign camp = TestDataFactory.createCampaign('Async Camp', true);
    insert camp;

    List<Session__c> sessions = new List<Session__c>();
    sessions.add(TestDataFactory.createSession(camp.Id, 'S1', true));
    sessions.add(TestDataFactory.createSession(camp.Id, 'S2', true));
    // Required speaker fields
    for (Integer i = 0; i < sessions.size(); i++) {
      sessions[i].PrimarySpeakerName__c = 'Speaker ' + i;
      sessions[i].PrimarySpeakerEmail__c = 'speaker' + i + '@test.com';
    }
    insert sessions;

    User evaluator = TestDataFactory.createUser(
      'Async',
      'AsyncUser',
      'async.user' + System.currentTimeMillis() + '@test.com',
      'Standard User'
    );
    insert evaluator;

    List<SessionEvaluation__c> evals = new List<SessionEvaluation__c>();
    for (Session__c s : sessions) {
      evals.add(
        TestDataFactory.createSessionEvaluationWithScores(
          s.Id,
          evaluator.Id,
          null,
          4,
          4,
          4,
          'Submitted'
        )
      );
      evals.add(
        TestDataFactory.createSessionEvaluationWithScores(
          s.Id,
          evaluator.Id,
          null,
          5,
          5,
          5,
          'Submitted'
        )
      );
    }
    insert evals;

    // When: call future method and run asynchronous queue
    Test.startTest();
    SessionAggregationService.aggregateSessionsAsync(
      new Set<Id>{ sessions[0].Id, sessions[1].Id }
    );
    Test.stopTest();

    // Then: both sessions should be aggregated
    List<Session__c> results = [
      SELECT Id, EvaluationsSubmitted__c, FinalScore__c
      FROM Session__c
      WHERE Id IN :sessions
    ];

    for (Session__c r : results) {
      System.assertEquals(
        2,
        r.EvaluationsSubmitted__c.intValue(),
        'Should have 2 submitted evaluations'
      );
      // FinalScore should be sum of three averages: (4+5)/2 * 3 = (4.5+4.5+4.5) = 13.5
      System.assert(r.FinalScore__c > 0, 'Final score should be calculated');
    }
  }

  @IsTest
  static void testRecalculateExpectedCounts() {
    // Given: campaign, sessions and two evaluator runs (one active, one inactive)
    Campaign camp = TestDataFactory.createCampaign('Expect Camp', true);
    insert camp;

    List<Session__c> sessions = TestDataFactory.createSessions(
      camp.Id,
      3,
      true
    );
    for (Integer i = 0; i < sessions.size(); i++) {
      sessions[i].PrimarySpeakerName__c = 'Speaker ' + i;
      sessions[i].PrimarySpeakerEmail__c = 'speaker' + i + '@test.com';
    }
    insert sessions;

    // Create two evaluator users
    User ev1 = TestDataFactory.createUser(
      'Ev',
      'OneUser',
      'ev.one' + System.currentTimeMillis() + '@test.com',
      'Standard User'
    );
    User ev2 = TestDataFactory.createUser(
      'Ev',
      'TwoUser',
      'ev.two' + System.currentTimeMillis() + '@test.com',
      'Standard User'
    );
    insert new List<User>{ ev1, ev2 };

    // Create runs: one active, one inactive
    EvaluatorRun__c run1 = TestDataFactory.createEvaluatorRun(
      camp.Id,
      ev1.Id,
      sessions.size()
    );
    EvaluatorRun__c run2 = TestDataFactory.createEvaluatorRun(
      camp.Id,
      ev2.Id,
      sessions.size()
    );
    run2.Active__c = false;
    insert new List<EvaluatorRun__c>{ run1, run2 };

    // When
    Test.startTest();
    SessionAggregationService.recalculateExpectedCounts(camp.Id);
    Test.stopTest();

    // Then: Sessions.EvaluationsExpected__c should equal count of active runs (1)
    List<Session__c> updated = [
      SELECT Id, EvaluationsExpected__c
      FROM Session__c
      WHERE Campaign__c = :camp.Id
    ];
    for (Session__c s : updated) {
      System.assertEquals(
        1,
        s.EvaluationsExpected__c.intValue(),
        'Expected count should match active runs'
      );
    }
  }
}
