/**
 * @description Test data factory for creating test records across all test classes
 * Provides reusable methods to create Campaigns, Sessions, Evaluations, Contacts, etc.
 * @group Testing
 */
@IsTest
public class TestDataFactory {
  /**
   * @description Create a test Campaign
   * @param name Campaign name (optional, defaults to 'Test Campaign')
   * @param isActive Whether campaign is active
   * @return Campaign record (not inserted)
   */
  public static Campaign createCampaign(String name, Boolean isActive) {
    return new Campaign(
      Name = name != null ? name : 'Test Campaign',
      IsActive = isActive != null ? isActive : true,
      Status = 'In Progress',
      Type = 'Conference'
    );
  }

  /**
   * @description Create multiple test Campaigns
   * @param count Number of campaigns to create
   * @return List of Campaign records (not inserted)
   */
  public static List<Campaign> createCampaigns(Integer count) {
    List<Campaign> campaigns = new List<Campaign>();
    for (Integer i = 0; i < count; i++) {
      campaigns.add(createCampaign('Test Campaign ' + i, true));
    }
    return campaigns;
  }

  /**
   * @description Create a test Session
   * @param campaignId Campaign ID to associate with
   * @param name Session name
   * @param selected Whether session is selected
   * @return Session__c record (not inserted)
   */
  public static Session__c createSession(
    Id campaignId,
    String name,
    Boolean selected
  ) {
    return new Session__c(
      Name = name != null ? name : 'Test Session',
      Campaign__c = campaignId,
      Selected__c = selected != null ? selected : false,
      Title__c = 'Test Session Title',
      Abstract__c = 'Test session abstract',
      Category__c = 'Development',
      DurationMinutes__c = 60
    );
  }

  /**
   * @description Create a session with speaker information
   * @param campaignId Campaign ID
   * @param name Session name
   * @param primarySpeakerName Primary speaker name
   * @param primarySpeakerEmail Primary speaker email
   * @param selected Whether session is selected
   * @return Session__c record (not inserted)
   */
  public static Session__c createSessionWithSpeaker(
    Id campaignId,
    String name,
    String primarySpeakerName,
    String primarySpeakerEmail,
    Boolean selected
  ) {
    Session__c session = createSession(campaignId, name, selected);
    session.PrimarySpeakerName__c = primarySpeakerName;
    session.PrimarySpeakerEmail__c = primarySpeakerEmail;
    session.PrimarySpeakerJobTitle__c = 'Speaker';
    session.PrimarySpeakerBio__c = 'Test bio for ' + primarySpeakerName;
    return session;
  }

  /**
   * @description Create a session with both primary and co-speaker
   * @param campaignId Campaign ID
   * @param name Session name
   * @param primarySpeakerName Primary speaker name
   * @param primarySpeakerEmail Primary speaker email
   * @param coSpeakerName Co-speaker name
   * @param coSpeakerEmail Co-speaker email
   * @param selected Whether session is selected
   * @return Session__c record (not inserted)
   */
  public static Session__c createSessionWithBothSpeakers(
    Id campaignId,
    String name,
    String primarySpeakerName,
    String primarySpeakerEmail,
    String coSpeakerName,
    String coSpeakerEmail,
    Boolean selected
  ) {
    Session__c session = createSessionWithSpeaker(
      campaignId,
      name,
      primarySpeakerName,
      primarySpeakerEmail,
      selected
    );
    session.CoSpeakerName__c = coSpeakerName;
    session.CoSpeakerEmail__c = coSpeakerEmail;
    session.CoSpeakerJobTitle__c = 'Co-Speaker';
    session.CoSpeakerBio__c = 'Test bio for ' + coSpeakerName;
    return session;
  }

  /**
   * @description Create multiple test Sessions
   * @param campaignId Campaign ID to associate with
   * @param count Number of sessions to create
   * @param selected Whether sessions are selected
   * @return List of Session__c records (not inserted)
   */
  public static List<Session__c> createSessions(
    Id campaignId,
    Integer count,
    Boolean selected
  ) {
    List<Session__c> sessions = new List<Session__c>();
    for (Integer i = 0; i < count; i++) {
      sessions.add(createSession(campaignId, 'Test Session ' + i, selected));
    }
    return sessions;
  }

  /**
   * @description Create a test Contact
   * @param firstName First name
   * @param lastName Last name
   * @param email Email address
   * @return Contact record (not inserted)
   */
  public static Contact createContact(
    String firstName,
    String lastName,
    String email
  ) {
    return new Contact(
      FirstName = firstName,
      LastName = lastName,
      Email = email,
      Title = 'Test Title'
    );
  }

  /**
   * @description Create multiple test Contacts
   * @param count Number of contacts to create
   * @return List of Contact records (not inserted)
   */
  public static List<Contact> createContacts(Integer count) {
    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < count; i++) {
      contacts.add(
        createContact(
          'FirstName' + i,
          'LastName' + i,
          'test' + i + '@example.com'
        )
      );
    }
    return contacts;
  }

  /**
   * @description Create a test Account
   * @param name Account name
   * @return Account record (not inserted)
   */
  public static Account createAccount(String name) {
    return new Account(
      Name = name != null ? name : 'Test Account',
      Industry = 'Technology'
    );
  }

  /**
   * @description Create a test User
   * @param firstName First name
   * @param lastName Last name
   * @param email Email
   * @param profileName Profile name (defaults to 'Standard User')
   * @return User record (not inserted)
   */
  public static User createUser(
    String firstName,
    String lastName,
    String email,
    String profileName
  ) {
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = :profileName
      LIMIT 1
    ];

    String uniqueName = email.substringBefore('@') + System.currentTimeMillis();

    return new User(
      FirstName = firstName,
      LastName = lastName,
      Email = email,
      Username = uniqueName + '@testorg.com',
      Alias = firstName.substring(0, 1) + lastName.substring(0, 4),
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      ProfileId = p.Id,
      LanguageLocaleKey = 'en_US'
    );
  }

  /**
   * @description Create a test EvaluatorRun
   * @param campaignId Campaign ID
   * @param evaluatorId User ID of evaluator
   * @param targetCount Target session count
   * @return EvaluatorRun__c record (not inserted)
   */
  public static EvaluatorRun__c createEvaluatorRun(
    Id campaignId,
    Id evaluatorId,
    Integer targetCount
  ) {
    return new EvaluatorRun__c(
      Campaign__c = campaignId,
      Evaluator__c = evaluatorId,
      Status__c = 'In_Progress',
      Active__c = true,
      TargetSessionCount__c = targetCount != null ? targetCount : 10,
      StartedAt__c = System.now(),
      SubmittedCount__c = 0,
      FlaggedCount__c = 0
    );
  }

  /**
   * @description Create multiple test EvaluatorRuns
   * @param campaignId Campaign ID
   * @param evaluatorIds List of evaluator User IDs
   * @param targetCount Target session count for each run
   * @return List of EvaluatorRun__c records (not inserted)
   */
  public static List<EvaluatorRun__c> createEvaluatorRuns(
    Id campaignId,
    List<Id> evaluatorIds,
    Integer targetCount
  ) {
    List<EvaluatorRun__c> runs = new List<EvaluatorRun__c>();
    for (Id evaluatorId : evaluatorIds) {
      runs.add(createEvaluatorRun(campaignId, evaluatorId, targetCount));
    }
    return runs;
  }

  /**
   * @description Create a test SessionEvaluation
   * @param sessionId Session ID
   * @param evaluatorId Evaluator User ID
   * @param runId EvaluatorRun ID (optional)
   * @param status Status (Draft, Submitted, etc.)
   * @return SessionEvaluation__c record (not inserted)
   */
  public static SessionEvaluation__c createSessionEvaluation(
    Id sessionId,
    Id evaluatorId,
    Id runId,
    String status
  ) {
    return new SessionEvaluation__c(
      Session__c = sessionId,
      Evaluator__c = evaluatorId,
      Run__c = runId,
      Status__c = status != null ? status : 'Draft',
      ClarityScore__c = 3,
      DiversityScore__c = 3,
      EngagementScore__c = 3
    );
  }

  /**
   * @description Create multiple SessionEvaluations for different sessions
   * @param sessionIds List of Session IDs
   * @param evaluatorId Evaluator User ID
   * @param runId EvaluatorRun ID (optional)
   * @param status Status
   * @return List of SessionEvaluation__c records (not inserted)
   */
  public static List<SessionEvaluation__c> createSessionEvaluations(
    List<Id> sessionIds,
    Id evaluatorId,
    Id runId,
    String status
  ) {
    List<SessionEvaluation__c> evaluations = new List<SessionEvaluation__c>();
    for (Id sessionId : sessionIds) {
      evaluations.add(
        createSessionEvaluation(sessionId, evaluatorId, runId, status)
      );
    }
    return evaluations;
  }

  /**
   * @description Create a SessionEvaluation with specific scores
   * @param sessionId Session ID
   * @param evaluatorId Evaluator User ID
   * @param runId EvaluatorRun ID (optional)
   * @param clarity Clarity score (1-5)
   * @param diversity Diversity score (1-5)
   * @param engagement Engagement score (1-5)
   * @param status Status
   * @return SessionEvaluation__c record (not inserted)
   */
  public static SessionEvaluation__c createSessionEvaluationWithScores(
    Id sessionId,
    Id evaluatorId,
    Id runId,
    Integer clarity,
    Integer diversity,
    Integer engagement,
    String status
  ) {
    SessionEvaluation__c eval = createSessionEvaluation(
      sessionId,
      evaluatorId,
      runId,
      status
    );
    eval.ClarityScore__c = clarity;
    eval.DiversityScore__c = diversity;
    eval.EngagementScore__c = engagement;
    return eval;
  }
}
