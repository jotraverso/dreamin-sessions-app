/**
 * @description Controller class for Campaign Session Selection App
 * Provides methods to fetch sessions, update selections, and convert speakers to contacts
 */
public with sharing class CampaignSessionController {
  /**
   * @description Wrapper class for session data returned to LWC
   */
  public class SessionWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String abstractText;
    @AuraEnabled
    public String language;
    @AuraEnabled
    public String level;
    @AuraEnabled
    public String category;
    @AuraEnabled
    public String mainCategory;
    @AuraEnabled
    public Integer duration;
    @AuraEnabled
    public Decimal finalScore;
    @AuraEnabled
    public Decimal clarityAvg;
    @AuraEnabled
    public Decimal contentAvg;
    @AuraEnabled
    public Decimal engagementAvg;
    @AuraEnabled
    public String selectionStatus;
    @AuraEnabled
    public String primarySpeakerName;
    @AuraEnabled
    public String primarySpeakerEmail;
    @AuraEnabled
    public String coSpeakerName;
    @AuraEnabled
    public String coSpeakerEmail;
  }

  /**
   * @description Wrapper class for campaign data
   */
  public class CampaignWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public Integer maxSelectedSessions;
    @AuraEnabled
    public Integer maxReserveSessions;
  }

  /**
   * @description Wrapper class for speaker to contact conversion
   */
  public class SpeakerWrapper {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String jobTitle;
    @AuraEnabled
    public String bio;
    @AuraEnabled
    public Boolean isPrimary;
    @AuraEnabled
    public Id contactId;
  }

  /**
   * @description Get campaign details by Id
   * @param campaignId Campaign record Id
   * @return CampaignWrapper with campaign data
   */
  @AuraEnabled(cacheable=true)
  public static CampaignWrapper getCampaignDetails(Id campaignId) {
    try {
      Campaign camp = [
        SELECT Id, Name, MaxSelectedSessions__c, MaxReserveSessions__c
        FROM Campaign
        WHERE Id = :campaignId
        LIMIT 1
      ];

      CampaignWrapper wrapper = new CampaignWrapper();
      wrapper.id = camp.Id;
      wrapper.name = camp.Name;
      wrapper.maxSelectedSessions = Integer.valueOf(camp.MaxSelectedSessions__c);
      wrapper.maxReserveSessions = Integer.valueOf(camp.MaxReserveSessions__c);

      return wrapper;
    } catch (Exception e) {
      throw new AuraHandledException('Error fetching campaign: ' + e.getMessage());
    }
  }

  /**
   * @description Get all sessions for a campaign ordered by Final Score descending
   * @param campaignId Campaign record Id
   * @return List of SessionWrapper
   */
  @AuraEnabled(cacheable=true)
  public static List<SessionWrapper> getSessions(Id campaignId) {
    try {
      List<Session__c> sessions = [
        SELECT
          Id,
          Name,
          Title__c,
          Abstract__c,
          Language__c,
          Level__c,
          Category__c,
          MainCategory__c,
          DurationMinutes__c,
          FinalScore__c,
          ClarityAvg__c,
          ContentAvg__c,
          EngagementAvg__c,
          Selection_Status__c,
          PrimarySpeakerName__c,
          PrimarySpeakerEmail__c,
          CoSpeakerName__c,
          CoSpeakerEmail__c
        FROM Session__c
        WHERE Campaign__c = :campaignId
        ORDER BY FinalScore__c DESC NULLS LAST
      ];

      List<SessionWrapper> wrappers = new List<SessionWrapper>();
      for (Session__c session : sessions) {
        SessionWrapper wrapper = new SessionWrapper();
        wrapper.id = session.Id;
        wrapper.name = session.Name;
        wrapper.title = session.Title__c;
        wrapper.abstractText = session.Abstract__c;
        wrapper.language = session.Language__c;
        wrapper.level = session.Level__c;
        wrapper.category = session.Category__c;
        wrapper.mainCategory = session.MainCategory__c;
        wrapper.duration = Integer.valueOf(session.DurationMinutes__c);
        wrapper.finalScore = session.FinalScore__c;
        wrapper.clarityAvg = session.ClarityAvg__c;
        wrapper.contentAvg = session.ContentAvg__c;
        wrapper.engagementAvg = session.EngagementAvg__c;
        wrapper.selectionStatus = session.Selection_Status__c != null ? session.Selection_Status__c : 'Not Selected';
        wrapper.primarySpeakerName = session.PrimarySpeakerName__c;
        wrapper.primarySpeakerEmail = session.PrimarySpeakerEmail__c;
        wrapper.coSpeakerName = session.CoSpeakerName__c;
        wrapper.coSpeakerEmail = session.CoSpeakerEmail__c;
        wrappers.add(wrapper);
      }

      return wrappers;
    } catch (Exception e) {
      throw new AuraHandledException('Error fetching sessions: ' + e.getMessage());
    }
  }

  /**
   * @description Update session selection status
   * @param sessionId Session record Id
   * @param selectionStatus Selection status value (Not Selected, Selected, Reserve)
   * @param mainCategory Main category value
   */
  @AuraEnabled
  public static void updateSessionSelection(Id sessionId, String selectionStatus, String mainCategory) {
    try {
      Session__c session = new Session__c(Id = sessionId, Selection_Status__c = selectionStatus, MainCategory__c = mainCategory);
      update session;
    } catch (Exception e) {
      throw new AuraHandledException('Error updating session: ' + e.getMessage());
    }
  }

  /**
   * @description Bulk update sessions selection status
   * @param sessionUpdates List of session Ids with their selection status
   */
  @AuraEnabled
  public static void updateSessionSelections(List<Map<String, Object>> sessionUpdates) {
    try {
      List<Session__c> sessionsToUpdate = new List<Session__c>();

      for (Map<String, Object> sessionData : sessionUpdates) {
        Session__c session = new Session__c(
          Id = (Id) sessionData.get('id'),
          Selection_Status__c = (String) sessionData.get('selectionStatus'),
          MainCategory__c = (String) sessionData.get('mainCategory')
        );
        sessionsToUpdate.add(session);
      }

      if (!sessionsToUpdate.isEmpty()) {
        update sessionsToUpdate;
      }
    } catch (Exception e) {
      throw new AuraHandledException('Error updating sessions: ' + e.getMessage());
    }
  }

  /**
   * @description Get speakers for a session
   * @param sessionId Session record Id
   * @return List of SpeakerWrapper
   */
  @AuraEnabled
  public static List<SpeakerWrapper> getSessionSpeakers(Id sessionId) {
    try {
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
        LIMIT 1
      ];

      List<SpeakerWrapper> speakers = new List<SpeakerWrapper>();

      if (String.isNotBlank(session.PrimarySpeakerName__c)) {
        SpeakerWrapper primary = new SpeakerWrapper();
        primary.name = session.PrimarySpeakerName__c;
        primary.email = session.PrimarySpeakerEmail__c;
        primary.jobTitle = session.PrimarySpeakerJobTitle__c;
        primary.bio = session.PrimarySpeakerBio__c;
        primary.isPrimary = true;
        primary.contactId = session.PrimarySpeakerContact__c;
        speakers.add(primary);
      }

      if (String.isNotBlank(session.CoSpeakerName__c)) {
        SpeakerWrapper coSpeaker = new SpeakerWrapper();
        coSpeaker.name = session.CoSpeakerName__c;
        coSpeaker.email = session.CoSpeakerEmail__c;
        coSpeaker.jobTitle = session.CoSpeakerJobTitle__c;
        coSpeaker.bio = session.CoSpeakerBio__c;
        coSpeaker.isPrimary = false;
        coSpeaker.contactId = session.CoSpeakerContact__c;
        speakers.add(coSpeaker);
      }

      return speakers;
    } catch (Exception e) {
      throw new AuraHandledException('Error fetching speakers: ' + e.getMessage());
    }
  }

  /**
   * @description Convert a single speaker to a contact or update existing contact, and update session speaker info
   * @param sessionId Session record Id
   * @param speakerData Speaker data to convert/update
   * @param isPrimary Whether this is the primary speaker
   * @param existingContactId Existing contact Id (null if creating new)
   * @return Contact Id (created or updated)
   */
  @AuraEnabled
  public static Id convertSpeakerToContact(Id sessionId, Map<String, String> speakerData, Boolean isPrimary, Id existingContactId) {
    try {
      Contact contact;

      if (existingContactId != null) {
        // Update existing contact
        contact = new Contact(
          Id = existingContactId,
          FirstName = speakerData.get('firstName'),
          LastName = speakerData.get('lastName'),
          Email = speakerData.get('email'),
          Title = speakerData.get('jobTitle'),
          Description = speakerData.get('bio')
        );
        update contact;
      } else {
        // Create new contact
        contact = new Contact(
          FirstName = speakerData.get('firstName'),
          LastName = speakerData.get('lastName'),
          Email = speakerData.get('email'),
          Title = speakerData.get('jobTitle'),
          Description = speakerData.get('bio')
        );
        insert contact;
      }

      // Update the session with the contact ID and speaker information
      String fullName = speakerData.get('firstName') + ' ' + speakerData.get('lastName');
      Session__c sessionToUpdate = new Session__c(Id = sessionId);

      if (isPrimary) {
        sessionToUpdate.PrimarySpeakerContact__c = contact.Id;
        sessionToUpdate.PrimarySpeakerName__c = fullName;
        sessionToUpdate.PrimarySpeakerEmail__c = speakerData.get('email');
        sessionToUpdate.PrimarySpeakerJobTitle__c = speakerData.get('jobTitle');
        sessionToUpdate.PrimarySpeakerBio__c = speakerData.get('bio');
      } else {
        sessionToUpdate.CoSpeakerContact__c = contact.Id;
        sessionToUpdate.CoSpeakerName__c = fullName;
        sessionToUpdate.CoSpeakerEmail__c = speakerData.get('email');
        sessionToUpdate.CoSpeakerJobTitle__c = speakerData.get('jobTitle');
        sessionToUpdate.CoSpeakerBio__c = speakerData.get('bio');
      }
      update sessionToUpdate;

      return contact.Id;
    } catch (Exception e) {
      throw new AuraHandledException('Error converting speaker: ' + e.getMessage());
    }
  }

  /**
   * @description Convert speakers to contacts (batch operation)
   * @param sessionId Session record Id
   * @param speakers List of speaker data to convert
   * @return List of created Contact Ids
   */
  @AuraEnabled
  public static List<Id> convertSpeakersToContacts(Id sessionId, List<Map<String, String>> speakers) {
    try {
      List<Contact> contactsToCreate = new List<Contact>();

      for (Map<String, String> speakerData : speakers) {
        Contact contact = new Contact(
          FirstName = speakerData.get('firstName'),
          LastName = speakerData.get('lastName'),
          Email = speakerData.get('email'),
          Title = speakerData.get('jobTitle'),
          Description = speakerData.get('bio')
        );
        contactsToCreate.add(contact);
      }

      if (!contactsToCreate.isEmpty()) {
        insert contactsToCreate;
      }

      List<Id> contactIds = new List<Id>();
      for (Contact c : contactsToCreate) {
        contactIds.add(c.Id);
      }

      return contactIds;
    } catch (Exception e) {
      throw new AuraHandledException('Error converting speakers: ' + e.getMessage());
    }
  }

  /**
   * @description Get category picklist values
   * @return List of category values
   */
  @AuraEnabled(cacheable=true)
  public static List<String> getCategoryPicklistValues() {
    List<String> categories = new List<String>();
    Schema.DescribeFieldResult fieldResult = Session__c.Category__c.getDescribe();
    List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();

    for (Schema.PicklistEntry entry : entries) {
      categories.add(entry.getValue());
    }

    return categories;
  }
}
