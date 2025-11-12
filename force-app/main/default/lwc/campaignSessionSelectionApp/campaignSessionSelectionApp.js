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

  // Event handlers
  async handleSelectionChange(event) {
    const { sessionId, selectionStatus, mainCategory, isAutoToggle } = event.detail;
    console.log("Selection change event received:", { sessionId, selectionStatus, mainCategory, isAutoToggle });

    // Don't validate limits if this is an auto-toggle from the child component
    if (!isAutoToggle) {
      // Validate limits before updating
      if (selectionStatus === "Selected" && this.selectedCount >= this.campaign.maxSelectedSessions) {
        this.showErrorToast(`Cannot select more than ${this.campaign.maxSelectedSessions} sessions`);
        return;
      }

      if (selectionStatus === "Reserve" && this.reserveCount >= this.campaign.maxReserveSessions) {
        this.showErrorToast(`Cannot mark more than ${this.campaign.maxReserveSessions} sessions as reserve`);
        return;
      }
    }

    // Update local state
    this.sessions = this.sessions.map((session) => {
      if (session.id === sessionId) {
        return { ...session, selectionStatus, mainCategory };
      }
      return session;
    });
    this.filteredSessions = [...this.sessions];

    // Auto-save the change immediately
    try {
      console.log("Saving session update...");
      const updates = [{ id: sessionId, selectionStatus, mainCategory }];
      await updateSessionSelections({ sessionUpdates: updates });
      console.log("Save successful");

      // Refresh sessions data
      await refreshApex(this.wiredSessionsResult);
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
    this.showSuccessToast("Speakers converted to contacts successfully");
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
