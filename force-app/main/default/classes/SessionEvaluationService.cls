/**
 * @description Service class for managing session evaluations
 * Handles retrieval, submission, and management of individual evaluations
 */
public with sharing class SessionEvaluationService {
  /**
   * @description DTO for public session information (excludes PII)
   */
  public class SessionDTO {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String title { get; set; }
    @AuraEnabled
    public String abstractText { get; set; }
    @AuraEnabled
    public String level { get; set; }
    @AuraEnabled
    public String category { get; set; }
    @AuraEnabled
    public Integer durationMinutes { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public Decimal clarityAvg { get; set; }
    @AuraEnabled
    public Decimal diversityAvg { get; set; }
    @AuraEnabled
    public Decimal engagementAvg { get; set; }
    @AuraEnabled
    public Decimal finalScore { get; set; }
  }

  /**
   * @description DTO for evaluation submission
   */
  public class EvaluationDTO {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public Id sessionId { get; set; }
    @AuraEnabled
    public Id evaluatorId { get; set; }
    @AuraEnabled
    public Id runId { get; set; }
    @AuraEnabled
    public Integer clarityScore { get; set; }
    @AuraEnabled
    public Integer diversityScore { get; set; }
    @AuraEnabled
    public Integer engagementScore { get; set; }
    @AuraEnabled
    public String comments { get; set; }
    @AuraEnabled
    public Boolean flagged { get; set; }
    @AuraEnabled
    public String skipReason { get; set; }
    @AuraEnabled
    public String status { get; set; }
  }

  /**
   * @description Get next session for evaluator to evaluate
   * @param campaignId Campaign ID
   * @return SessionDTO or null if no sessions remaining
   */
  @AuraEnabled
  public static SessionDTO getNextSessionForEvaluator(Id campaignId) {
    Id userId = UserInfo.getUserId();

    // Get all session IDs already evaluated with 'Submitted' status
    Set<Id> evaluatedSessionIds = new Set<Id>();
    for (SessionEvaluation__c se : [
      SELECT Session__c
      FROM SessionEvaluation__c
      WHERE Evaluator__c = :userId AND Status__c = 'Submitted'
    ]) {
      evaluatedSessionIds.add(se.Session__c);
    }

    // Find next unevaluated session
    List<Session__c> sessions = [
      SELECT
        Id,
        Title__c,
        Abstract__c,
        Level__c,
        Category__c,
        DurationMinutes__c,
        Status__c,
        ClarityAvg__c,
        DiversityAvg__c,
        EngagementAvg__c,
        FinalScore__c
      FROM Session__c
      WHERE Campaign__c = :campaignId AND Status__c != 'Selected' AND Status__c != 'Not_Selected' AND Id NOT IN :evaluatedSessionIds
      ORDER BY SubmissionDateTime__c ASC
      LIMIT 1
    ];

    if (sessions.isEmpty()) {
      return null;
    }

    return mapToDTO(sessions[0]);
  }

  /**
   * @description Get public sessions list for campaign
   * @param campaignId Campaign ID (optional)
   * @return List of SessionDTO
   */
  @AuraEnabled(cacheable=true)
  public static List<SessionDTO> getPublicSessions(Id campaignId) {
    String query =
      'SELECT Id, Title__c, Abstract__c, Level__c, Category__c, ' +
      'DurationMinutes__c, Status__c, ClarityAvg__c, ' +
      'DiversityAvg__c, EngagementAvg__c, FinalScore__c ' +
      'FROM Session__c';

    if (campaignId != null) {
      query += ' WHERE Campaign__c = :campaignId';
    }

    query += ' ORDER BY Title__c ASC LIMIT 200';

    List<Session__c> sessions = Database.query(query);
    List<SessionDTO> result = new List<SessionDTO>();

    for (Session__c session : sessions) {
      result.add(mapToDTO(session));
    }

    return result;
  }

  /**
   * @description Save draft evaluation
   * @param evaluationData JSON string of EvaluationDTO
   * @return Evaluation record ID
   */
  @AuraEnabled
  public static Id saveDraft(String evaluationData) {
    EvaluationDTO dto = (EvaluationDTO) JSON.deserialize(evaluationData, EvaluationDTO.class);

    SessionEvaluation__c eval = new SessionEvaluation__c();

    if (dto.id != null) {
      eval.Id = dto.id;
    } else {
      eval.Session__c = dto.sessionId;
      eval.Evaluator__c = dto.evaluatorId != null ? dto.evaluatorId : UserInfo.getUserId();
      eval.Run__c = dto.runId;
    }

    eval.ClarityScore__c = dto.clarityScore;
    eval.DiversityScore__c = dto.diversityScore;
    eval.EngagementScore__c = dto.engagementScore;
    eval.Comments__c = dto.comments;
    eval.Flagged__c = dto.flagged != null ? dto.flagged : false;
    eval.SkipReason__c = dto.skipReason;
    eval.Status__c = 'Draft';

    upsert eval;

    return eval.Id;
  }

  /**
   * @description Submit evaluation (transitions from Draft to Submitted)
   * @param evaluationId Evaluation record ID
   */
  @AuraEnabled
  public static void submitEvaluation(Id evaluationId) {
    SessionEvaluation__c eval = [
      SELECT Id, ClarityScore__c, DiversityScore__c, EngagementScore__c, Status__c, FinalizedSnapshot__c
      FROM SessionEvaluation__c
      WHERE Id = :evaluationId
      FOR UPDATE
    ];

    // Validate not finalized
    if (eval.FinalizedSnapshot__c) {
      throw new AuraHandledException('Cannot modify finalized evaluation');
    }

    // Validate scores are present
    if (eval.ClarityScore__c == null || eval.DiversityScore__c == null || eval.EngagementScore__c == null) {
      throw new AuraHandledException('All scores must be provided');
    }

    // Validate score ranges
    validateScoreRanges(eval);

    eval.Status__c = 'Submitted';
    eval.SubmittedDate__c = System.now();

    update eval;
  }

  /**
   * @description Submit evaluation with inline data (creates and submits in one call)
   * @param inputJson JSON string containing session and scores
   */
  @AuraEnabled
  public static void submitEvaluationWithData(String inputJson) {
    Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(inputJson);

    Id sessionId = (Id) data.get('sessionId');
    Integer clarity = (Integer) data.get('clarity');
    Integer diversity = (Integer) data.get('diversity');
    Integer engagement = (Integer) data.get('engagement');
    String comments = (String) data.get('comments');

    SessionEvaluation__c eval = new SessionEvaluation__c(
      Session__c = sessionId,
      Evaluator__c = UserInfo.getUserId(),
      ClarityScore__c = clarity,
      DiversityScore__c = diversity,
      EngagementScore__c = engagement,
      Comments__c = comments,
      Status__c = 'Submitted',
      SubmittedDate__c = System.now()
    );

    insert eval;
  }

  /**
   * @description Flag session for follow-up
   * @param evaluationId Evaluation record ID
   * @param reason Flag reason
   */
  @AuraEnabled
  public static void flagSession(Id evaluationId, String reason) {
    SessionEvaluation__c eval = new SessionEvaluation__c(Id = evaluationId, Flagged__c = true, Comments__c = reason);

    update eval;
  }

  /**
   * @description Finalize evaluator run (locks all evaluations)
   * @param runId EvaluatorRun ID
   */
  @AuraEnabled
  public static void finalizeRun(Id runId) {
    EvaluatorRun__c run = [
      SELECT Id, Status__c, AllSubmitted__c, FinalizedAt__c
      FROM EvaluatorRun__c
      WHERE Id = :runId
      FOR UPDATE
    ];

    if (run.FinalizedAt__c != null) {
      throw new AuraHandledException('Run already finalized');
    }

    // Update all evaluations to finalized
    List<SessionEvaluation__c> evals = [
      SELECT Id, FinalizedSnapshot__c
      FROM SessionEvaluation__c
      WHERE Run__c = :runId
    ];

    for (SessionEvaluation__c eval : evals) {
      eval.FinalizedSnapshot__c = true;
    }

    update evals;

    // Update run status
    run.Status__c = 'Finalized';
    run.FinalizedAt__c = System.now();
    run.FinalizationToken__c = generateToken();

    update run;
  }

  /**
   * @description Get session evaluations for review
   * @param runId EvaluatorRun ID (optional - if not provided, returns for current user)
   * @return List of SessionEvaluation records with Session details
   */
  @AuraEnabled
  public static List<SessionEvaluation__c> getSessionEvaluations(Id runId) {
    Id userId = UserInfo.getUserId();

    if (runId != null) {
      return [
        SELECT
          Id,
          Session__c,
          Session__r.Title__c,
          Session__r.Abstract__c,
          Session__r.Level__c,
          Session__r.Category__c,
          Session__r.DurationMinutes__c,
          ClarityScore__c,
          DiversityScore__c,
          EngagementScore__c,
          TotalScore__c,
          Comments__c,
          Flagged__c,
          Status__c,
          SubmittedDate__c
        FROM SessionEvaluation__c
        WHERE Run__c = :runId
        ORDER BY SubmittedDate__c ASC NULLS LAST
      ];
    } else {
      // Return empty list if no runId provided
      return new List<SessionEvaluation__c>();
    }
  }

  /**
   * @description Update evaluation scores and flag status
   * @param evaluationId Evaluation record ID
   * @param clarity Clarity score
   * @param diversity Diversity score
   * @param engagement Engagement score
   * @param comments Comments
   * @param flagged Flag status
   */
  @AuraEnabled(cacheable=false)
  public static void updateEvaluationScores(
    Id evaluationId,
    Integer clarity,
    Integer diversity,
    Integer engagement,
    String comments,
    Boolean flagged
  ) {
    SessionEvaluation__c eval = [
      SELECT Id, Status__c, FinalizedSnapshot__c, Run__c
      FROM SessionEvaluation__c
      WHERE Id = :evaluationId
      FOR UPDATE
    ];

    if (eval.FinalizedSnapshot__c) {
      throw new AuraHandledException('Cannot modify finalized evaluation');
    }

    eval.ClarityScore__c = clarity;
    eval.DiversityScore__c = diversity;
    eval.EngagementScore__c = engagement;
    eval.Comments__c = comments;
    eval.Flagged__c = flagged;

    // Set status based on flag status
    if (flagged) {
      eval.Status__c = 'Draft';
    } else {
      eval.Status__c = 'Submitted';
      eval.SubmittedDate__c = System.now();
      // Only validate score ranges when not flagged (submitting)
      validateScoreRanges(eval);
    }

    update eval;

    // Update run counts
    if (eval.Run__c != null) {
      updateRunCounts(eval.Run__c);
    }
  }

  /**
   * @description Get evaluator progress summary by run ID
   * @param runId EvaluatorRun ID
   * @return Map with progress metrics
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getEvaluatorProgressByRun(Id runId) {
    EvaluatorRun__c run = [
      SELECT Id, TotalAssigned__c, SubmittedCount__c, FlaggedCount__c, PercentComplete__c, Status__c
      FROM EvaluatorRun__c
      WHERE Id = :runId
      LIMIT 1
    ];

    Map<String, Object> result = new Map<String, Object>();
    result.put('runId', run.Id);
    result.put('targetCount', run.TotalAssigned__c);
    result.put('submittedCount', run.SubmittedCount__c);
    result.put('flaggedCount', run.FlaggedCount__c);
    result.put('percentComplete', run.PercentComplete__c);
    result.put('status', run.Status__c);

    return result;
  }

  /**
   * @description Get evaluator progress summary
   * @param campaignId Campaign ID
   * @return Map with progress metrics
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getEvaluatorProgress(Id campaignId) {
    Id userId = UserInfo.getUserId();

    EvaluatorRun__c run = [
      SELECT Id, TotalAssigned__c, SubmittedCount__c, FlaggedCount__c, PercentComplete__c, Status__c
      FROM EvaluatorRun__c
      WHERE Campaign__c = :campaignId AND Evaluator__c = :userId
      LIMIT 1
    ];

    Map<String, Object> result = new Map<String, Object>();
    result.put('runId', run.Id);
    result.put('targetCount', run.TotalAssigned__c);
    result.put('submittedCount', run.SubmittedCount__c);
    result.put('flaggedCount', run.FlaggedCount__c);
    result.put('percentComplete', run.PercentComplete__c);
    result.put('status', run.Status__c);

    return result;
  }

  // Helper methods

  private static SessionDTO mapToDTO(Session__c session) {
    SessionDTO dto = new SessionDTO();
    dto.id = session.Id;
    dto.title = session.Title__c;
    dto.abstractText = session.Abstract__c;
    dto.level = session.Level__c;
    dto.category = session.Category__c;
    dto.durationMinutes = Integer.valueOf(session.DurationMinutes__c);
    dto.status = session.Status__c;
    dto.clarityAvg = session.ClarityAvg__c;
    dto.diversityAvg = session.DiversityAvg__c;
    dto.engagementAvg = session.EngagementAvg__c;
    dto.finalScore = session.FinalScore__c;

    return dto;
  }

  private static void validateScoreRanges(SessionEvaluation__c eval) {
    if (eval.ClarityScore__c < 1 || eval.ClarityScore__c > 20) {
      throw new AuraHandledException('Clarity score must be between 1 and 20');
    }
    if (eval.DiversityScore__c < 1 || eval.DiversityScore__c > 10) {
      throw new AuraHandledException('Diversity score must be between 1 and 10');
    }
    if (eval.EngagementScore__c < 1 || eval.EngagementScore__c > 20) {
      throw new AuraHandledException('Engagement score must be between 1 and 20');
    }
  }

  private static String generateToken() {
    Blob b = Crypto.generateAesKey(128);
    String token = EncodingUtil.convertToHex(b);
    return token.substring(0, 32);
  }

  /**
   * @description Update EvaluatorRun counts based on current evaluations
   * @param runId EvaluatorRun ID
   */
  private static void updateRunCounts(Id runId) {
    // Count submitted evaluations
    Integer submittedCount = [
      SELECT COUNT()
      FROM SessionEvaluation__c
      WHERE Run__c = :runId AND Status__c = 'Submitted'
    ];

    // Count flagged evaluations
    Integer flaggedCount = [
      SELECT COUNT()
      FROM SessionEvaluation__c
      WHERE Run__c = :runId AND Flagged__c = TRUE
    ];

    // Update the run
    EvaluatorRun__c run = new EvaluatorRun__c(Id = runId, SubmittedCount__c = submittedCount, FlaggedCount__c = flaggedCount);

    update run;
  }
}
