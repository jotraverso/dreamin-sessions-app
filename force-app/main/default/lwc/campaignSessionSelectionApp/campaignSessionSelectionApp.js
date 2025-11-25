import { LightningElement, api, wire, track } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCampaignDetails from "@salesforce/apex/CampaignSessionController.getCampaignDetails";
import getSessions from "@salesforce/apex/CampaignSessionController.getSessions";
import updateSessionSelections from "@salesforce/apex/CampaignSessionController.updateSessionSelections";
import getCategoryPicklistValues from "@salesforce/apex/CampaignSessionController.getCategoryPicklistValues";

export default class CampaignSessionSelectionApp extends LightningElement {
  @api recordId; // Campaign Id from the Lightning page

  @track selectedCampaignId; // Campaign Id from lookup selector
  @track campaign = {};
  @track sessions = [];
  @track filteredSessions = [];
  @track categoryOptions = [];
  @track selectedSession = null;
  @track selectedSessionId = null;

  showDetailsModal = false;
  showConvertModal = false;

  // Store wired results for refresh
  wiredSessionsResult;

  // Compute effective campaign ID
  get effectiveCampaignId() {
    return this.recordId || this.selectedCampaignId;
  }

  get hasRecordId() {
    return !!this.recordId;
  }

  get mainContentColumnClass() {
    // Full width when on record page, 2/3 width in standalone app
    return this.hasRecordId ? "slds-col slds-size_1-of-1 slds-p-horizontal_small" : "slds-col slds-size_2-of-3 slds-p-horizontal_small";
  }

  // Wire campaign details
  @wire(getCampaignDetails, { campaignId: "$effectiveCampaignId" })
  wiredCampaign({ error, data }) {
    if (data) {
      this.campaign = data;
    } else if (error) {
      this.showErrorToast("Error loading campaign: " + error.body.message);
    }
  }

  // Wire sessions
  @wire(getSessions, { campaignId: "$effectiveCampaignId" })
  wiredSessions(result) {
    this.wiredSessionsResult = result;
    const { error, data } = result;
    if (data) {
      this.sessions = data.map((session) => ({
        ...session,
        // Set default main category if not set
        mainCategory: session.mainCategory || this.getFirstCategory(session.category)
      }));
      this.filteredSessions = [...this.sessions];
    } else if (error) {
      this.showErrorToast("Error loading sessions: " + error.body.message);
    }
  }

  // Wire category picklist values
  @wire(getCategoryPicklistValues)
  wiredCategories({ error, data }) {
    if (data) {
      this.categoryOptions = data.map((cat) => ({ label: cat, value: cat }));
    } else if (error) {
      console.error("Error loading categories:", error);
    }
  }

  // Computed properties
  get selectedCount() {
    return this.sessions.filter((s) => s.selectionStatus === "Selected").length;
  }

  get reserveCount() {
    return this.sessions.filter((s) => s.selectionStatus === "Reserve").length;
  }

  get categoryStats() {
    const stats = {};
    this.sessions
      .filter((s) => s.selectionStatus === "Selected")
      .forEach((session) => {
        const cat = session.mainCategory || "Uncategorized";
        stats[cat] = (stats[cat] || 0) + 1;
      });
    return Object.entries(stats).map(([label, value]) => ({ label, value }));
  }

  get languageStats() {
    const stats = {};
    this.sessions
      .filter((s) => s.selectionStatus === "Selected")
      .forEach((session) => {
        const lang = session.language || "Unknown";
        stats[lang] = (stats[lang] || 0) + 1;
      });
    return Object.entries(stats).map(([label, value]) => ({ label, value }));
  }

  get hasCategoryStats() {
    return this.categoryStats && this.categoryStats.length > 0;
  }

  get hasLanguageStats() {
    return this.languageStats && this.languageStats.length > 0;
  }

  get hasAnyStats() {
    return this.hasCategoryStats || this.hasLanguageStats;
  }

  // Helper method to get first category from multiselect
  getFirstCategory(categoryString) {
    if (!categoryString) return null;
    const categories = categoryString.split(";");
    return categories[0] || null;
  }

  // Selection limit validation
  validateSelectionLimits(selectionStatus, isStatusChanging) {
    if (isStatusChanging && selectionStatus === "Selected" && this.selectedCount >= this.campaign.maxSelectedSessions) {
      this.showErrorToast(`Cannot select more than ${this.campaign.maxSelectedSessions} sessions`);
      return false;
    }
    if (isStatusChanging && selectionStatus === "Reserve" && this.reserveCount >= this.campaign.maxReserveSessions) {
      this.showErrorToast(`Cannot mark more than ${this.campaign.maxReserveSessions} sessions as reserve`);
      return false;
    }
    return true;
  }

  // Duplicate contact detection across selected sessions
  checkDuplicateSpeakerContacts(sessionId, session) {
    const dupMessages = [];
    const { primarySpeakerContactId, coSpeakerContactId } = session;

    if (primarySpeakerContactId) {
      const match = this.findDuplicateContactSession(sessionId, primarySpeakerContactId);
      if (match) {
        const role = match.primarySpeakerContactId === primarySpeakerContactId ? "primary" : "co-speaker";
        dupMessages.push(`Primary speaker also linked as ${role} on '${match.title || match.name}'`);
      }
    }

    if (coSpeakerContactId) {
      const match = this.findDuplicateContactSession(sessionId, coSpeakerContactId);
      if (match) {
        const role = match.primarySpeakerContactId === coSpeakerContactId ? "primary" : "co-speaker";
        dupMessages.push(`Co-speaker also linked as ${role} on '${match.title || match.name}'`);
      }
    }

    if (dupMessages.length > 0) {
      this.showWarningToast(`Contact duplication detected: ${dupMessages.join("; ")}`);
    }
  }

  // Find another selected session with the same contact ID
  findDuplicateContactSession(excludeSessionId, contactId) {
    return this.sessions.find(
      (s) =>
        s.id !== excludeSessionId &&
        s.selectionStatus === "Selected" &&
        (s.primarySpeakerContactId === contactId || s.coSpeakerContactId === contactId)
    );
  }

  // Update local session state
  updateLocalSessionState(sessionId, selectionStatus, mainCategory) {
    this.sessions = this.sessions.map((session) => (session.id === sessionId ? { ...session, selectionStatus, mainCategory } : session));
    this.filteredSessions = [...this.sessions];
  }

  // Persist session selection to server
  async saveSessionSelection(sessionId, selectionStatus, mainCategory) {
    const updates = [{ id: sessionId, selectionStatus, mainCategory }];
    await updateSessionSelections({ sessionUpdates: updates });
    await refreshApex(this.wiredSessionsResult);
  }

  // Event handlers
  async handleSelectionChange(event) {
    const { sessionId, selectionStatus, mainCategory, isAutoToggle } = event.detail;
    console.log("Selection change event received:", { sessionId, selectionStatus, mainCategory, isAutoToggle });

    if (!isAutoToggle) {
      const previousSession = this.sessions.find((s) => s.id === sessionId);
      const isStatusChanging = previousSession?.selectionStatus !== selectionStatus;

      if (!this.validateSelectionLimits(selectionStatus, isStatusChanging)) {
        return;
      }

      if (isStatusChanging && selectionStatus === "Selected" && previousSession) {
        this.checkDuplicateSpeakerContacts(sessionId, previousSession);
      }
    }

    this.updateLocalSessionState(sessionId, selectionStatus, mainCategory);

    try {
      console.log("Saving session update...");
      await this.saveSessionSelection(sessionId, selectionStatus, mainCategory);
      console.log("Save successful");
    } catch (error) {
      console.error("Error saving session:", error);
      this.showErrorToast("Error saving session: " + (error.body?.message || error.message));
    }
  }

  handleViewDetails(event) {
    const sessionId = event.detail.sessionId;
    this.selectedSession = this.sessions.find((s) => s.id === sessionId);
    this.showDetailsModal = true;
  }

  handleConvertSpeakers(event) {
    this.selectedSessionId = event.detail.sessionId;
    this.showConvertModal = true;
  }

  handleCloseDetailsModal() {
    this.showDetailsModal = false;
    this.selectedSession = null;
  }

  handleCloseConvertModal() {
    this.showConvertModal = false;
    this.selectedSessionId = null;
  }

  handleCampaignChange(event) {
    const { campaignId } = event.detail;
    this.selectedCampaignId = campaignId;
  }

  handleSpeakersConverted() {
    this.showConvertModal = false;
    this.selectedSessionId = null;
    // Refresh sessions so newly linked contact IDs are available for duplicate detection
    if (this.wiredSessionsResult) {
      refreshApex(this.wiredSessionsResult)
        .then(() => {
          this.filteredSessions = [...this.sessions];
          this.showSuccessToast("Speakers converted to contacts successfully");
        })
        .catch((error) => {
          console.error("Error refreshing sessions after conversion", error);
          this.showWarningToast("Converted but failed to refresh sessions; warnings may be delayed");
        });
    } else {
      this.showSuccessToast("Speakers converted to contacts successfully");
    }
  }

  handleShowToast(event) {
    const { title, message, variant } = event.detail;
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }

  // Toast helper methods
  showSuccessToast(message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Success",
        message: message,
        variant: "success"
      })
    );
  }

  showErrorToast(message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Error",
        message: message,
        variant: "error",
        mode: "sticky"
      })
    );
  }

  showWarningToast(message) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Warning",
        message: message,
        variant: "warning"
      })
    );
  }
}
