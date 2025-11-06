/**
 * @description Service class for converting selected sessions to Contacts
 * Creates Contact records for speakers of selected sessions
 */
public with sharing class ContactConversionService {
  /**
   * @description Result DTO for conversion operations
   */
  public class ConversionResult {
    @AuraEnabled
    public Integer created { get; set; }
    @AuraEnabled
    public Integer matched { get; set; }
    @AuraEnabled
    public Integer errors { get; set; }
    @AuraEnabled
    public List<String> errorMessages { get; set; }

    public ConversionResult() {
      this.created = 0;
      this.matched = 0;
      this.errors = 0;
      this.errorMessages = new List<String>();
    }
  }

  /**
   * @description Convert all selected sessions in a campaign to Contacts
   * @param campaignId Campaign ID
   * @return ConversionResult with statistics
   */
  @AuraEnabled
  public static ConversionResult convertSelectedSessions(Id campaignId) {
    ConversionResult result = new ConversionResult();

    List<Session__c> selectedSessions = [
      SELECT
        Id,
        PrimarySpeakerName__c,
        PrimarySpeakerEmail__c,
        PrimarySpeakerJobTitle__c,
        PrimarySpeakerBio__c,
        PrimarySpeakerContact__c,
        CoSpeakerName__c,
        CoSpeakerEmail__c,
        CoSpeakerJobTitle__c,
        CoSpeakerBio__c,
        CoSpeakerContact__c
      FROM Session__c
      WHERE Campaign__c = :campaignId AND Selected__c = TRUE
    ];

    List<Session__c> sessionsToUpdate = new List<Session__c>();

    for (Session__c session : selectedSessions) {
      try {
        // Process primary speaker
        if (
          String.isNotBlank(session.PrimarySpeakerEmail__c) &&
          session.PrimarySpeakerContact__c == null
        ) {
          Id contactId = findOrCreateContact(
            session.PrimarySpeakerName__c,
            session.PrimarySpeakerEmail__c,
            session.PrimarySpeakerJobTitle__c,
            session.PrimarySpeakerBio__c,
            result
          );

          if (contactId != null) {
            session.PrimarySpeakerContact__c = contactId;
            sessionsToUpdate.add(session);
          }
        }

        // Process co-speaker
        if (
          String.isNotBlank(session.CoSpeakerEmail__c) &&
          session.CoSpeakerContact__c == null
        ) {
          Id contactId = findOrCreateContact(
            session.CoSpeakerName__c,
            session.CoSpeakerEmail__c,
            session.CoSpeakerJobTitle__c,
            session.CoSpeakerBio__c,
            result
          );

          if (contactId != null) {
            session.CoSpeakerContact__c = contactId;
            if (!sessionsToUpdate.contains(session)) {
              sessionsToUpdate.add(session);
            }
          }
        }
      } catch (Exception e) {
        result.errors++;
        result.errorMessages.add(
          'Session ' + session.Id + ': ' + e.getMessage()
        );
      }
    }

    if (!sessionsToUpdate.isEmpty()) {
      update sessionsToUpdate;
    }

    return result;
  }

  /**
   * @description Convert a single session to Contacts
   * @param sessionId Session ID
   */
  @AuraEnabled
  public static void convertSession(Id sessionId) {
    Session__c session = [
      SELECT
        Id,
        PrimarySpeakerName__c,
        PrimarySpeakerEmail__c,
        PrimarySpeakerJobTitle__c,
        PrimarySpeakerBio__c,
        PrimarySpeakerContact__c,
        CoSpeakerName__c,
        CoSpeakerEmail__c,
        CoSpeakerJobTitle__c,
        CoSpeakerBio__c,
        CoSpeakerContact__c
      FROM Session__c
      WHERE Id = :sessionId
    ];

    ConversionResult result = new ConversionResult();

    // Process primary speaker
    if (String.isNotBlank(session.PrimarySpeakerEmail__c)) {
      Id contactId = findOrCreateContact(
        session.PrimarySpeakerName__c,
        session.PrimarySpeakerEmail__c,
        session.PrimarySpeakerJobTitle__c,
        session.PrimarySpeakerBio__c,
        result
      );

      if (contactId != null) {
        session.PrimarySpeakerContact__c = contactId;
      }
    }

    // Process co-speaker
    if (String.isNotBlank(session.CoSpeakerEmail__c)) {
      Id contactId = findOrCreateContact(
        session.CoSpeakerName__c,
        session.CoSpeakerEmail__c,
        session.CoSpeakerJobTitle__c,
        session.CoSpeakerBio__c,
        result
      );

      if (contactId != null) {
        session.CoSpeakerContact__c = contactId;
      }
    }

    update session;
  }

  // Helper methods

  private static Id findOrCreateContact(
    String name,
    String email,
    String title,
    String bio,
    ConversionResult result
  ) {
    // Build candidate contact for duplicate detection
    Contact candidateContact = buildCandidateContact(name, email, title, bio);

    // Use Salesforce Duplicate Detection API to find duplicates
    try {
      Id existingContactId = findExistingDuplicate(candidateContact);

      if (existingContactId != null) {
        result.matched++;
        return existingContactId;
      }

      // No duplicates found, create new contact
      if (!Schema.sObjectType.Contact.isCreateable()) {
        throw new SecurityException(
          'Insufficient permissions to create Contact'
        );
      }

      insert candidateContact;
      result.created++;
      return candidateContact.Id;
    } catch (Exception e) {
      result.errors++;
      result.errorMessages.add(
        'Failed to process contact for ' + email + ': ' + e.getMessage()
      );
      return null;
    }
  }

  private static Contact buildCandidateContact(
    String name,
    String email,
    String title,
    String bio
  ) {
    Contact candidateContact = new Contact();

    // Parse name into FirstName and LastName
    if (String.isNotBlank(name)) {
      List<String> nameParts = name.trim().split(' ', 2);
      if (nameParts.size() == 1) {
        candidateContact.LastName = nameParts[0];
      } else {
        candidateContact.FirstName = nameParts[0];
        candidateContact.LastName = nameParts[1];
      }
    } else {
      candidateContact.LastName = 'Unknown';
    }

    candidateContact.Email = email;
    candidateContact.Title = title;
    candidateContact.Description = bio;

    return candidateContact;
  }

  private static Id findExistingDuplicate(Contact candidateContact) {
    List<Datacloud.FindDuplicatesResult> duplicateResults = Datacloud.FindDuplicates.findDuplicates(
      new List<Contact>{ candidateContact }
    );

    if (duplicateResults.isEmpty()) {
      return null;
    }

    // Iterate through duplicate rules applied
    for (
      Datacloud.DuplicateResult dupeResult : duplicateResults[0]
        .getDuplicateResults()
    ) {
      // Check if this rule found any matches
      List<Datacloud.MatchResult> matchResults = dupeResult.getMatchResults();

      if (!matchResults.isEmpty()) {
        List<Datacloud.MatchRecord> matchRecords = matchResults[0]
          .getMatchRecords();

        if (!matchRecords.isEmpty()) {
          // Return the ID of the first matching contact
          return matchRecords[0].getRecord().Id;
        }
      }
    }

    return null;
  }
}
