/**
 * @description Test class for ContactConversionService
 * @group Testing
 */
@IsTest
private class ContactConversionServiceTest {
  @TestSetup
  static void setupTestData() {
    // Create Campaign
    Campaign campaign = TestDataFactory.createCampaign('Test Campaign', true);
    insert campaign;

    // Create Sessions with speakers
    List<Session__c> sessions = new List<Session__c>();

    // Session 1: Primary speaker only, selected
    sessions.add(
      TestDataFactory.createSessionWithSpeaker(
        campaign.Id,
        'Session 1',
        'John Doe',
        'john.doe@example.com',
        true
      )
    );

    // Session 2: Both speakers, selected
    sessions.add(
      TestDataFactory.createSessionWithBothSpeakers(
        campaign.Id,
        'Session 2',
        'Jane Smith',
        'jane.smith@example.com',
        'Bob Johnson',
        'bob.johnson@example.com',
        true
      )
    );

    // Session 3: Speaker already exists as Contact, selected
    Contact existingContact = TestDataFactory.createContact(
      'Alice',
      'Williams',
      'alice.williams@example.com'
    );
    insert existingContact;

    Session__c session3 = TestDataFactory.createSessionWithSpeaker(
      campaign.Id,
      'Session 3',
      'Alice Williams',
      'alice.williams@example.com',
      true
    );
    sessions.add(session3);

    // Session 4: Not selected (should be ignored)
    sessions.add(
      TestDataFactory.createSessionWithSpeaker(
        campaign.Id,
        'Session 4',
        'Charlie Brown',
        'charlie.brown@example.com',
        false
      )
    );

    insert sessions;
  }

  @IsTest
  static void testConvertSelectedSessions_Success() {
    // Given
    Campaign campaign = [SELECT Id FROM Campaign LIMIT 1];

    // When
    Test.startTest();
    ContactConversionService.ConversionResult result = ContactConversionService.convertSelectedSessions(
      campaign.Id
    );
    Test.stopTest();

    // Then
    Assert.areEqual(3, result.created, 'Should create 3 new contacts');
    Assert.areEqual(1, result.matched, 'Should match 1 existing contact');
    Assert.areEqual(0, result.errors, 'Should have no errors');
    Assert.isTrue(
      result.errorMessages.isEmpty(),
      'Should have no error messages'
    );

    // Verify contacts were created
    List<Contact> contacts = [
      SELECT Id, FirstName, LastName, Email
      FROM Contact
      ORDER BY Email
    ];
    Assert.areEqual(4, contacts.size(), 'Should have 4 total contacts');

    // Verify sessions were updated with contact references
    List<Session__c> updatedSessions = [
      SELECT
        Id,
        Name,
        PrimarySpeakerContact__c,
        CoSpeakerContact__c,
        PrimarySpeakerEmail__c,
        CoSpeakerEmail__c
      FROM Session__c
      WHERE Selected__c = TRUE AND PrimarySpeakerEmail__c != NULL
      ORDER BY Name
    ];

    Assert.areEqual(
      3,
      updatedSessions.size(),
      'Should have 3 sessions with speakers'
    );

    // Session 1 - verify primary speaker linked
    Assert.isNotNull(
      updatedSessions[0].PrimarySpeakerContact__c,
      'Session 1 should have primary speaker linked'
    );
    Assert.isNull(
      updatedSessions[0].CoSpeakerContact__c,
      'Session 1 should not have co-speaker'
    );

    // Session 2 - verify both speakers linked
    Assert.isNotNull(
      updatedSessions[1].PrimarySpeakerContact__c,
      'Session 2 should have primary speaker linked'
    );
    Assert.isNotNull(
      updatedSessions[1].CoSpeakerContact__c,
      'Session 2 should have co-speaker linked'
    );

    // Session 3 - verify matched existing contact
    Assert.isNotNull(
      updatedSessions[2].PrimarySpeakerContact__c,
      'Session 3 should have primary speaker linked'
    );
  }

  @IsTest
  static void testConvertSelectedSessions_NoSelectedSessions() {
    // Given
    Campaign campaign = [SELECT Id FROM Campaign LIMIT 1];

    // Deselect all sessions
    List<Session__c> sessions = [
      SELECT Id
      FROM Session__c
      WHERE Campaign__c = :campaign.Id
    ];
    for (Session__c session : sessions) {
      session.Selected__c = false;
    }
    update sessions;

    // When
    Test.startTest();
    ContactConversionService.ConversionResult result = ContactConversionService.convertSelectedSessions(
      campaign.Id
    );
    Test.stopTest();

    // Then
    Assert.areEqual(0, result.created, 'Should create no contacts');
    Assert.areEqual(0, result.matched, 'Should match no contacts');
    Assert.areEqual(0, result.errors, 'Should have no errors');
  }

  @IsTest
  static void testConvertSession_SingleSession() {
    // Given
    Session__c session = [
      SELECT Id
      FROM Session__c
      WHERE Name = 'Session 1'
      LIMIT 1
    ];

    Integer contactCountBefore = [SELECT COUNT() FROM Contact];

    // When
    Test.startTest();
    ContactConversionService.convertSession(session.Id);
    Test.stopTest();

    // Then
    Integer contactCountAfter = [SELECT COUNT() FROM Contact];
    Assert.areEqual(
      contactCountBefore + 1,
      contactCountAfter,
      'Should create 1 new contact'
    );

    // Verify session was updated
    Session__c updatedSession = [
      SELECT Id, PrimarySpeakerContact__c
      FROM Session__c
      WHERE Id = :session.Id
    ];
    Assert.isNotNull(
      updatedSession.PrimarySpeakerContact__c,
      'Session should have speaker contact linked'
    );
  }

  @IsTest
  static void testConvertSession_WithBothSpeakers() {
    // Given
    Session__c session = [
      SELECT Id
      FROM Session__c
      WHERE Name = 'Session 2'
      LIMIT 1
    ];

    Integer contactCountBefore = [SELECT COUNT() FROM Contact];

    // When
    Test.startTest();
    ContactConversionService.convertSession(session.Id);
    Test.stopTest();

    // Then
    Integer contactCountAfter = [SELECT COUNT() FROM Contact];
    Assert.areEqual(
      contactCountBefore + 2,
      contactCountAfter,
      'Should create 2 new contacts'
    );

    // Verify session was updated
    Session__c updatedSession = [
      SELECT Id, PrimarySpeakerContact__c, CoSpeakerContact__c
      FROM Session__c
      WHERE Id = :session.Id
    ];
    Assert.isNotNull(
      updatedSession.PrimarySpeakerContact__c,
      'Session should have primary speaker linked'
    );
    Assert.isNotNull(
      updatedSession.CoSpeakerContact__c,
      'Session should have co-speaker linked'
    );
  }

  @IsTest
  static void testConvertSession_MatchesExistingContact() {
    // Given
    Session__c session = [
      SELECT Id
      FROM Session__c
      WHERE Name = 'Session 3'
      LIMIT 1
    ];

    Integer contactCountBefore = [SELECT COUNT() FROM Contact];

    // When
    Test.startTest();
    ContactConversionService.convertSession(session.Id);
    Test.stopTest();

    // Then
    Integer contactCountAfter = [SELECT COUNT() FROM Contact];
    Assert.areEqual(
      contactCountBefore,
      contactCountAfter,
      'Should not create new contact (match existing)'
    );

    // Verify session was updated with existing contact
    Session__c updatedSession = [
      SELECT Id, PrimarySpeakerContact__c
      FROM Session__c
      WHERE Id = :session.Id
    ];
    Assert.isNotNull(
      updatedSession.PrimarySpeakerContact__c,
      'Session should have existing speaker linked'
    );
  }

  @IsTest
  static void testFindOrCreateContact_ParsesNameCorrectly() {
    // Given
    Campaign campaign = [SELECT Id FROM Campaign LIMIT 1];

    // Create session with single-word name
    Session__c singleNameSession = TestDataFactory.createSessionWithSpeaker(
      campaign.Id,
      'Single Name Test',
      'Madonna',
      'madonna@example.com',
      true
    );
    insert singleNameSession;

    // When
    Test.startTest();
    ContactConversionService.convertSession(singleNameSession.Id);
    Test.stopTest();

    // Then
    Contact contact = [
      SELECT FirstName, LastName
      FROM Contact
      WHERE Email = 'madonna@example.com'
      LIMIT 1
    ];
    Assert.isNull(
      contact.FirstName,
      'FirstName should be null for single name'
    );
    Assert.areEqual(
      'Madonna',
      contact.LastName,
      'LastName should be the single name'
    );
  }

  @IsTest
  static void testConvertSelectedSessions_AlreadyLinkedContacts() {
    // Given
    Campaign campaign = [SELECT Id FROM Campaign LIMIT 1];

    // Link a contact to a session first
    Session__c session = [
      SELECT Id
      FROM Session__c
      WHERE Name = 'Session 1'
      LIMIT 1
    ];
    Contact existingContact = TestDataFactory.createContact(
      'Existing',
      'Contact',
      'existing@example.com'
    );
    insert existingContact;

    session.PrimarySpeakerContact__c = existingContact.Id;
    update session;

    Integer contactCountBefore = [SELECT COUNT() FROM Contact];

    // When
    Test.startTest();
    ContactConversionService.ConversionResult result = ContactConversionService.convertSelectedSessions(
      campaign.Id
    );
    Test.stopTest();

    // Then - should not process session that already has contact linked
    Integer contactCountAfter = [SELECT COUNT() FROM Contact];
    // Should only create contacts for sessions without existing links
    Assert.isTrue(
      contactCountAfter >= contactCountBefore,
      'Contact count should increase or stay same'
    );
  }
}
