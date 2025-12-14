/**
 * @description Test class for CampaignSessionController
 * Tests all controller methods including campaign details, session retrieval,
 * selection updates, speaker management, and evaluation progress tracking
 */
@IsTest
private class CampaignSessionControllerTest {
  @IsTest
  static void testGetCampaignDetails() {
    // Given: campaign with max selected and reserve values
    Campaign camp = TestDataFactory.createCampaign('Test Campaign', true);
    camp.MaxSelectedSessions__c = 10;
    camp.MaxReserveSessions__c = 5;
    insert camp;

    // When
    Test.startTest();
    CampaignSessionController.CampaignWrapper result = CampaignSessionController.getCampaignDetails(camp.Id);
    Test.stopTest();

    // Then
    System.assertNotEquals(null, result, 'Should return campaign wrapper');
    System.assertEquals(camp.Id, result.id, 'Campaign Id should match');
    System.assertEquals('Test Campaign', result.name, 'Campaign name should match');
    System.assertEquals(10, result.maxSelectedSessions, 'Max selected sessions should match');
    System.assertEquals(5, result.maxReserveSessions, 'Max reserve sessions should match');
  }

  @IsTest
  static void testGetSessions() {
    // Given: campaign with multiple sessions
    Campaign camp = TestDataFactory.createCampaign('Session Camp', true);
    insert camp;

    List<Session__c> sessions = new List<Session__c>();
    sessions.add(TestDataFactory.createSessionWithSpeaker(camp.Id, 'Session 1', 'Speaker A', 'speakera@test.com', false));
    sessions.add(TestDataFactory.createSessionWithSpeaker(camp.Id, 'Session 2', 'Speaker B', 'speakerb@test.com', true));
    sessions.add(TestDataFactory.createSessionWithSpeaker(camp.Id, 'Session 3', 'Speaker C', 'speakerc@test.com', false));

    // Set different final scores to test ordering
    sessions[0].FinalScore__c = 8.5;
    sessions[1].FinalScore__c = 12.0;
    sessions[2].FinalScore__c = 10.2;

    // Set selection status
    sessions[0].Selection_Status__c = 'Selected';
    sessions[1].Selection_Status__c = 'Reserve';

    insert sessions;

    // When
    Test.startTest();
    List<CampaignSessionController.SessionWrapper> results = CampaignSessionController.getSessions(camp.Id);
    Test.stopTest();

    // Then: verify sessions ordered by FinalScore__c DESC
    System.assertEquals(3, results.size(), 'Should return 3 sessions');
    System.assertEquals(sessions[1].Id, results[0].id, 'First should be highest score');
    System.assertEquals(12.0, results[0].finalScore, 'Highest score should be 12.0');
    System.assertEquals('Reserve', results[0].selectionStatus, 'First session selection status');

    System.assertEquals(sessions[2].Id, results[1].id, 'Second should be middle score');
    System.assertEquals(10.2, results[1].finalScore, 'Middle score should be 10.2');
    System.assertEquals('Not Selected', results[1].selectionStatus, 'Default selection status when null');

    System.assertEquals(sessions[0].Id, results[2].id, 'Third should be lowest score');
    System.assertEquals(8.5, results[2].finalScore, 'Lowest score should be 8.5');
    System.assertEquals('Selected', results[2].selectionStatus, 'Third session selection status');
  }

  @IsTest
  static void testGetSessionsWithSpeakerData() {
    // Given: session with detailed speaker information
    Campaign camp = TestDataFactory.createCampaign('Speaker Data Camp', true);
    insert camp;

    Contact primaryContact = TestDataFactory.createContact('John', 'Doe', 'john@test.com');
    Contact coContact = TestDataFactory.createContact('Jane', 'Smith', 'jane@test.com');
    insert new List<Contact>{ primaryContact, coContact };

    Session__c session = TestDataFactory.createSessionWithBothSpeakers(
      camp.Id,
      'Test Session',
      'John Doe',
      'john@test.com',
      'Jane Smith',
      'jane@test.com',
      false
    );
    session.PrimarySpeakerContact__c = primaryContact.Id;
    session.CoSpeakerContact__c = coContact.Id;
    session.ClarityAvg__c = 4.5;
    session.ContentAvg__c = 4.8;
    session.EngagementAvg__c = 4.2;
    session.Category__c = 'Development';
    session.MainCategory__c = 'Lightning';
    session.Level__c = 'Advanced';
    session.Language__c = 'English';
    session.DurationMinutes__c = 45;
    insert session;

    // When
    Test.startTest();
    List<CampaignSessionController.SessionWrapper> results = CampaignSessionController.getSessions(camp.Id);
    Test.stopTest();

    // Then: verify all speaker and session data
    System.assertEquals(1, results.size(), 'Should return 1 session');
    CampaignSessionController.SessionWrapper wrapper = results[0];

    System.assertEquals('John Doe', wrapper.primarySpeakerName, 'Primary speaker name');
    System.assertEquals('john@test.com', wrapper.primarySpeakerEmail, 'Primary speaker email');
    System.assertEquals(primaryContact.Id, wrapper.primarySpeakerContactId, 'Primary contact Id');

    System.assertEquals('Jane Smith', wrapper.coSpeakerName, 'Co-speaker name');
    System.assertEquals('jane@test.com', wrapper.coSpeakerEmail, 'Co-speaker email');
    System.assertEquals(coContact.Id, wrapper.coSpeakerContactId, 'Co-contact Id');

    System.assertEquals(4.5, wrapper.clarityAvg, 'Clarity average');
    System.assertEquals(4.8, wrapper.contentAvg, 'Content average');
    System.assertEquals(4.2, wrapper.engagementAvg, 'Engagement average');
    System.assertEquals('Development', wrapper.category, 'Category');
    System.assertEquals('Lightning', wrapper.mainCategory, 'Main category');
    System.assertEquals('Advanced', wrapper.level, 'Level');
    System.assertEquals('English', wrapper.language, 'Language');
    System.assertEquals(45, wrapper.duration, 'Duration');
  }

  @IsTest
  static void testUpdateSessionSelection() {
    // Given: session to update
    Campaign camp = TestDataFactory.createCampaign('Update Camp', true);
    insert camp;

    Session__c session = TestDataFactory.createSessionWithSpeaker(camp.Id, 'Update Session', 'Speaker X', 'speakerx@test.com', false);
    insert session;

    // When
    Test.startTest();
    CampaignSessionController.updateSessionSelection(session.Id, 'Selected', 'Lightning');
    Test.stopTest();

    // Then
    Session__c updated = [SELECT Id, Selection_Status__c, MainCategory__c FROM Session__c WHERE Id = :session.Id];
    System.assertEquals('Selected', updated.Selection_Status__c, 'Selection status should be updated');
    System.assertEquals('Lightning', updated.MainCategory__c, 'Main category should be updated');
  }

  @IsTest
  static void testUpdateSessionSelections() {
    // Given: multiple sessions to bulk update
    Campaign camp = TestDataFactory.createCampaign('Bulk Update Camp', true);
    insert camp;

    List<Session__c> sessions = new List<Session__c>();
    sessions.add(TestDataFactory.createSessionWithSpeaker(camp.Id, 'Bulk 1', 'Speaker 1', 'speaker1@test.com', false));
    sessions.add(TestDataFactory.createSessionWithSpeaker(camp.Id, 'Bulk 2', 'Speaker 2', 'speaker2@test.com', false));
    sessions.add(TestDataFactory.createSessionWithSpeaker(camp.Id, 'Bulk 3', 'Speaker 3', 'speaker3@test.com', false));
    insert sessions;

    // When
    List<Map<String, Object>> sessionUpdates = new List<Map<String, Object>>();
    sessionUpdates.add(new Map<String, Object>{ 'id' => sessions[0].Id, 'selectionStatus' => 'Selected', 'mainCategory' => 'Admin' });
    sessionUpdates.add(new Map<String, Object>{ 'id' => sessions[1].Id, 'selectionStatus' => 'Reserve', 'mainCategory' => 'Development' });
    sessionUpdates.add(new Map<String, Object>{ 'id' => sessions[2].Id, 'selectionStatus' => 'Not Selected', 'mainCategory' => 'Integration' });

    Test.startTest();
    CampaignSessionController.updateSessionSelections(sessionUpdates);
    Test.stopTest();

    // Then
    List<Session__c> updated = [SELECT Id, Selection_Status__c, MainCategory__c FROM Session__c WHERE Id IN :sessions ORDER BY Name];
    System.assertEquals('Selected', updated[0].Selection_Status__c, 'First session status');
    System.assertEquals('Admin', updated[0].MainCategory__c, 'First session category');

    System.assertEquals('Reserve', updated[1].Selection_Status__c, 'Second session status');
    System.assertEquals('Development', updated[1].MainCategory__c, 'Second session category');

    System.assertEquals('Not Selected', updated[2].Selection_Status__c, 'Third session status');
    System.assertEquals('Integration', updated[2].MainCategory__c, 'Third session category');
  }

  @IsTest
  static void testGetSessionSpeakers() {
    // Given: session with both speakers
    Campaign camp = TestDataFactory.createCampaign('Speaker Camp', true);
    insert camp;

    Session__c session = TestDataFactory.createSessionWithBothSpeakers(
      camp.Id,
      'Speaker Session',
      'Alice Johnson',
      'alice@test.com',
      'Bob Williams',
      'bob@test.com',
      false
    );
    insert session;

    // When
    Test.startTest();
    List<CampaignSessionController.SpeakerWrapper> speakers = CampaignSessionController.getSessionSpeakers(session.Id);
    Test.stopTest();

    // Then
    System.assertEquals(2, speakers.size(), 'Should return 2 speakers');

    CampaignSessionController.SpeakerWrapper primary = speakers[0];
    System.assertEquals('Alice Johnson', primary.name, 'Primary speaker name');
    System.assertEquals('alice@test.com', primary.email, 'Primary speaker email');
    System.assertEquals(true, primary.isPrimary, 'Should be primary');
    System.assertEquals(null, primary.contactId, 'No contact linked yet');

    CampaignSessionController.SpeakerWrapper coSpeaker = speakers[1];
    System.assertEquals('Bob Williams', coSpeaker.name, 'Co-speaker name');
    System.assertEquals('bob@test.com', coSpeaker.email, 'Co-speaker email');
    System.assertEquals(false, coSpeaker.isPrimary, 'Should not be primary');
    System.assertEquals(null, coSpeaker.contactId, 'No contact linked yet');
  }

  @IsTest
  static void testGetSessionSpeakersWithContacts() {
    // Given: session with speakers linked to contacts
    Campaign camp = TestDataFactory.createCampaign('Contact Speaker Camp', true);
    insert camp;

    Contact primaryContact = TestDataFactory.createContact('Primary', 'Speaker', 'primary@test.com');
    Contact coContact = TestDataFactory.createContact('Co', 'Speaker', 'co@test.com');
    insert new List<Contact>{ primaryContact, coContact };

    Session__c session = TestDataFactory.createSessionWithBothSpeakers(
      camp.Id,
      'Linked Session',
      'Primary Speaker',
      'primary@test.com',
      'Co Speaker',
      'co@test.com',
      false
    );
    session.PrimarySpeakerContact__c = primaryContact.Id;
    session.CoSpeakerContact__c = coContact.Id;
    insert session;

    // When
    Test.startTest();
    List<CampaignSessionController.SpeakerWrapper> speakers = CampaignSessionController.getSessionSpeakers(session.Id);
    Test.stopTest();

    // Then
    System.assertEquals(2, speakers.size(), 'Should return 2 speakers');
    System.assertEquals(primaryContact.Id, speakers[0].contactId, 'Primary contact should be linked');
    System.assertEquals(coContact.Id, speakers[1].contactId, 'Co-contact should be linked');
  }

  @IsTest
  static void testGetSpeakerDuplicates() {
    // Given: contacts with matching email
    Contact c1 = TestDataFactory.createContact('John', 'Doe', 'duplicate@test.com');
    Contact c2 = TestDataFactory.createContact('Jane', 'Doe', 'duplicate@test.com');
    Contact c3 = TestDataFactory.createContact('Jim', 'Doe', 'other@test.com');
    insert new List<Contact>{ c1, c2, c3 };

    // When
    Test.startTest();
    List<CampaignSessionController.ContactMatchWrapper> duplicates = CampaignSessionController.getSpeakerDuplicates('duplicate@test.com');
    Test.stopTest();

    // Then
    System.assertEquals(2, duplicates.size(), 'Should find 2 duplicates');
    System.assertEquals('duplicate@test.com', duplicates[0].email, 'Email should match');
    System.assertEquals('duplicate@test.com', duplicates[1].email, 'Email should match');
  }

  @IsTest
  static void testGetSpeakerDuplicatesNoMatches() {
    // Given: no matching contacts
    Contact c = TestDataFactory.createContact('Test', 'Contact', 'test@test.com');
    insert c;

    // When
    Test.startTest();
    List<CampaignSessionController.ContactMatchWrapper> duplicates = CampaignSessionController.getSpeakerDuplicates('nomatch@test.com');
    Test.stopTest();

    // Then
    System.assertEquals(0, duplicates.size(), 'Should find no duplicates');
  }

  @IsTest
  static void testGetSpeakerDuplicatesBlankEmail() {
    // When
    Test.startTest();
    List<CampaignSessionController.ContactMatchWrapper> duplicates = CampaignSessionController.getSpeakerDuplicates('');
    Test.stopTest();

    // Then
    System.assertEquals(0, duplicates.size(), 'Should return empty list for blank email');
  }

  @IsTest
  static void testLinkSessionSpeakerToContact() {
    // Given: session and existing contact
    Campaign camp = TestDataFactory.createCampaign('Link Camp', true);
    insert camp;

    Contact existingContact = TestDataFactory.createContact('Existing', 'Contact', 'existing@test.com');
    existingContact.Title = 'Senior Developer';
    existingContact.Description = 'Experienced speaker bio';
    insert existingContact;

    Session__c session = TestDataFactory.createSessionWithSpeaker(camp.Id, 'Link Session', 'Old Name', 'old@test.com', false);
    insert session;

    // When: link primary speaker to existing contact
    Test.startTest();
    Id returnedContactId = CampaignSessionController.linkSessionSpeakerToContact(session.Id, existingContact.Id, true);
    Test.stopTest();

    // Then: verify session updated with contact data
    System.assertEquals(existingContact.Id, returnedContactId, 'Should return contact Id');

    Session__c updated = [
      SELECT Id, PrimarySpeakerContact__c, PrimarySpeakerName__c, PrimarySpeakerEmail__c, PrimarySpeakerJobTitle__c, PrimarySpeakerBio__c
      FROM Session__c
      WHERE Id = :session.Id
    ];

    System.assertEquals(existingContact.Id, updated.PrimarySpeakerContact__c, 'Contact should be linked');
    System.assertEquals('Existing Contact', updated.PrimarySpeakerName__c, 'Name should be copied');
    System.assertEquals('existing@test.com', updated.PrimarySpeakerEmail__c, 'Email should be copied');
    System.assertEquals('Senior Developer', updated.PrimarySpeakerJobTitle__c, 'Job title should be copied');
    System.assertEquals('Experienced speaker bio', updated.PrimarySpeakerBio__c, 'Bio should be copied');
  }

  @IsTest
  static void testLinkSessionCoSpeakerToContact() {
    // Given: session and existing contact
    Campaign camp = TestDataFactory.createCampaign('CoSpeaker Link Camp', true);
    insert camp;

    Contact existingContact = TestDataFactory.createContact('Co', 'SpeakerContact', 'cospeaker@test.com');
    insert existingContact;

    Session__c session = TestDataFactory.createSessionWithBothSpeakers(
      camp.Id,
      'CoSpeaker Session',
      'Primary',
      'primary@test.com',
      'Old CoSpeaker',
      'oldco@test.com',
      false
    );
    insert session;

    // When: link co-speaker to existing contact
    Test.startTest();
    Id returnedContactId = CampaignSessionController.linkSessionSpeakerToContact(session.Id, existingContact.Id, false);
    Test.stopTest();

    // Then: verify co-speaker fields updated
    Session__c updated = [SELECT Id, CoSpeakerContact__c, CoSpeakerName__c, CoSpeakerEmail__c FROM Session__c WHERE Id = :session.Id];

    System.assertEquals(existingContact.Id, updated.CoSpeakerContact__c, 'Co-contact should be linked');
    System.assertEquals('Co SpeakerContact', updated.CoSpeakerName__c, 'Co-speaker name should be copied');
    System.assertEquals('cospeaker@test.com', updated.CoSpeakerEmail__c, 'Co-speaker email should be copied');
  }

  @IsTest
  static void testConvertSpeakerToContactNewContact() {
    // Given: session without linked contact
    Campaign camp = TestDataFactory.createCampaign('Convert Camp', true);
    insert camp;

    Session__c session = TestDataFactory.createSessionWithSpeaker(camp.Id, 'Convert Session', 'Old Speaker', 'old@test.com', false);
    insert session;

    // When: convert speaker to new contact
    Map<String, Object> speakerPayload = new Map<String, Object>{
      'isPrimary' => true,
      'existingContactId' => null,
      'firstName' => 'New',
      'lastName' => 'Speaker',
      'email' => 'newspeaker@test.com',
      'jobTitle' => 'Tech Lead',
      'bio' => 'New speaker bio'
    };

    Test.startTest();
    Id newContactId = CampaignSessionController.convertSpeakerToContact(session.Id, speakerPayload);
    Test.stopTest();

    // Then: verify new contact created and session updated
    System.assertNotEquals(null, newContactId, 'Should return new contact Id');

    Contact newContact = [SELECT Id, FirstName, LastName, Email, Title, Description FROM Contact WHERE Id = :newContactId];
    System.assertEquals('New', newContact.FirstName, 'First name should match');
    System.assertEquals('Speaker', newContact.LastName, 'Last name should match');
    System.assertEquals('newspeaker@test.com', newContact.Email, 'Email should match');
    System.assertEquals('Tech Lead', newContact.Title, 'Title should match');
    System.assertEquals('New speaker bio', newContact.Description, 'Bio should match');

    Session__c updated = [
      SELECT Id, PrimarySpeakerContact__c, PrimarySpeakerName__c, PrimarySpeakerEmail__c, PrimarySpeakerJobTitle__c, PrimarySpeakerBio__c
      FROM Session__c
      WHERE Id = :session.Id
    ];

    System.assertEquals(newContactId, updated.PrimarySpeakerContact__c, 'Contact should be linked');
    System.assertEquals('New Speaker', updated.PrimarySpeakerName__c, 'Session speaker name should be updated');
    System.assertEquals('newspeaker@test.com', updated.PrimarySpeakerEmail__c, 'Session speaker email should be updated');
  }

  @IsTest
  static void testConvertSpeakerToContactUpdateExisting() {
    // Given: session and existing contact to update
    Campaign camp = TestDataFactory.createCampaign('Update Convert Camp', true);
    insert camp;

    Contact existingContact = TestDataFactory.createContact('Old', 'Name', 'old@test.com');
    insert existingContact;

    Session__c session = TestDataFactory.createSessionWithSpeaker(camp.Id, 'Update Convert Session', 'Speaker', 'speaker@test.com', false);
    insert session;

    // When: update existing contact
    Map<String, Object> speakerPayload = new Map<String, Object>{
      'isPrimary' => true,
      'existingContactId' => existingContact.Id,
      'firstName' => 'Updated',
      'lastName' => 'Contact',
      'email' => 'updated@test.com',
      'jobTitle' => 'Updated Title',
      'bio' => 'Updated bio'
    };

    Test.startTest();
    Id returnedContactId = CampaignSessionController.convertSpeakerToContact(session.Id, speakerPayload);
    Test.stopTest();

    // Then: verify contact updated
    System.assertEquals(existingContact.Id, returnedContactId, 'Should return same contact Id');

    Contact updated = [SELECT Id, FirstName, LastName, Email, Title, Description FROM Contact WHERE Id = :existingContact.Id];
    System.assertEquals('Updated', updated.FirstName, 'First name should be updated');
    System.assertEquals('Contact', updated.LastName, 'Last name should be updated');
    System.assertEquals('updated@test.com', updated.Email, 'Email should be updated');
    System.assertEquals('Updated Title', updated.Title, 'Title should be updated');
    System.assertEquals('Updated bio', updated.Description, 'Bio should be updated');
  }

  @IsTest
  static void testConvertSpeakersToContacts() {
    // Given: session and multiple speakers to convert
    Campaign camp = TestDataFactory.createCampaign('Batch Convert Camp', true);
    insert camp;

    Session__c session = TestDataFactory.createSessionWithSpeaker(camp.Id, 'Batch Session', 'Speaker', 'speaker@test.com', false);
    insert session;

    // When: batch convert speakers
    List<Map<String, String>> speakers = new List<Map<String, String>>();
    speakers.add(
      new Map<String, String>{
        'firstName' => 'Batch1',
        'lastName' => 'Speaker1',
        'email' => 'batch1@test.com',
        'jobTitle' => 'Title1',
        'bio' => 'Bio1'
      }
    );
    speakers.add(
      new Map<String, String>{
        'firstName' => 'Batch2',
        'lastName' => 'Speaker2',
        'email' => 'batch2@test.com',
        'jobTitle' => 'Title2',
        'bio' => 'Bio2'
      }
    );

    Test.startTest();
    List<Id> contactIds = CampaignSessionController.convertSpeakersToContacts(session.Id, speakers);
    Test.stopTest();

    // Then: verify 2 contacts created
    System.assertEquals(2, contactIds.size(), 'Should create 2 contacts');

    List<Contact> created = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id IN :contactIds ORDER BY FirstName];
    System.assertEquals('Batch1', created[0].FirstName, 'First contact first name');
    System.assertEquals('Batch2', created[1].FirstName, 'Second contact first name');
  }

  @IsTest
  static void testGetCategoryPicklistValues() {
    // When
    Test.startTest();
    List<String> categories = CampaignSessionController.getCategoryPicklistValues();
    Test.stopTest();

    // Then
    System.assertNotEquals(null, categories, 'Should return list');
    System.assert(categories.size() > 0, 'Should have at least one category value');
  }

  @IsTest
  static void testGetEvaluationProgress() {
    // Given: campaign with evaluator runs
    Campaign camp = TestDataFactory.createCampaign('Progress Camp', true);
    insert camp;

    User evaluator1 = TestDataFactory.createUser('Eval', 'User1', 'eval1' + System.currentTimeMillis() + '@test.com', 'Standard User');
    User evaluator2 = TestDataFactory.createUser('Eval', 'User2', 'eval2' + System.currentTimeMillis() + '@test.com', 'Standard User');
    insert new List<User>{ evaluator1, evaluator2 };

    EvaluatorRun__c run1 = TestDataFactory.createEvaluatorRun(camp.Id, evaluator1.Id, 10);
    run1.SubmittedCount__c = 5;
    run1.FlaggedCount__c = 2;
    run1.Status__c = 'In Progress';

    EvaluatorRun__c run2 = TestDataFactory.createEvaluatorRun(camp.Id, evaluator2.Id, 8);
    run2.SubmittedCount__c = 8;
    run2.FlaggedCount__c = 0;
    run2.Status__c = 'Completed';

    insert new List<EvaluatorRun__c>{ run1, run2 };

    // When
    Test.startTest();
    List<CampaignSessionController.EvaluationProgressWrapper> progress = CampaignSessionController.getEvaluationProgress(camp.Id);
    Test.stopTest();

    // Then: verify progress data
    System.assertEquals(2, progress.size(), 'Should return 2 progress records');

    // Ordered by Evaluator__r.Name ASC - verify basic data is returned
    for (CampaignSessionController.EvaluationProgressWrapper p : progress) {
      System.assertNotEquals(null, p.runId, 'Run Id should be set');
      System.assertNotEquals(null, p.evaluatorName, 'Evaluator name should be set');
      System.assertNotEquals(null, p.status, 'Status should be set');
      System.assertNotEquals(null, p.lastModifiedDate, 'Last modified date should be set');
      // TotalEvaluations and PercentComplete are formula/rollup fields
      // Just verify they exist and have default values
      System.assert(p.totalEvaluations >= 0, 'Total evaluations should be >= 0');
      System.assert(p.percentComplete >= 0, 'Percent complete should be >= 0');
    }

    // Verify submitted and flagged counts that we set
    CampaignSessionController.EvaluationProgressWrapper p1 = progress[0];
    System.assertEquals(5, p1.submittedCount, 'Submitted count');
    System.assertEquals(2, p1.flaggedCount, 'Flagged count');
    System.assertEquals('In Progress', p1.status, 'Status');

    CampaignSessionController.EvaluationProgressWrapper p2 = progress[1];
    System.assertEquals(8, p2.submittedCount, 'Submitted count');
    System.assertEquals(0, p2.flaggedCount, 'Flagged count');
    System.assertEquals('Completed', p2.status, 'Status');
  }

  @IsTest
  static void testGetEvaluationProgressNoCampaign() {
    // When: null campaign id
    Test.startTest();
    List<CampaignSessionController.EvaluationProgressWrapper> progress = CampaignSessionController.getEvaluationProgress(null);
    Test.stopTest();

    // Then: return empty list
    System.assertEquals(0, progress.size(), 'Should return empty list for null campaign');
  }

  @IsTest
  static void testGetEvaluationProgressNoRuns() {
    // Given: campaign with no evaluator runs
    Campaign camp = TestDataFactory.createCampaign('No Runs Camp', true);
    insert camp;

    // When
    Test.startTest();
    List<CampaignSessionController.EvaluationProgressWrapper> progress = CampaignSessionController.getEvaluationProgress(camp.Id);
    Test.stopTest();

    // Then
    System.assertEquals(0, progress.size(), 'Should return empty list when no runs exist');
  }
}
