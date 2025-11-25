import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getSessionSpeakers from "@salesforce/apex/CampaignSessionController.getSessionSpeakers";
import convertSpeakerToContact from "@salesforce/apex/CampaignSessionController.convertSpeakerToContact";
import linkSessionSpeakerToContact from "@salesforce/apex/CampaignSessionController.linkSessionSpeakerToContact";

export default class ConvertSpeakersModal extends LightningElement {
  @api sessionId;

  @track speakers = [];
  @track loading = false;

  connectedCallback() {
    // Add ESC key listener
    window.addEventListener("keydown", this.handleKeyDownEvent);

    this.loadSpeakers();
  }

  disconnectedCallback() {
    // Remove ESC key listener
    window.removeEventListener("keydown", this.handleKeyDownEvent);
  }

  handleKeyDownEvent = (event) => {
    if (event.key === "Escape" || event.key === "Esc") {
      this.handleClose();
    }
  };

  handleBackdropClick(event) {
    // Close modal when clicking on backdrop (not the modal container)
    if (event.target.classList.contains("slds-backdrop")) {
      this.handleClose();
    }
  }

  async loadSpeakers() {
    this.loading = true;

    try {
      const result = await getSessionSpeakers({ sessionId: this.sessionId });
      this.speakers = result.map((speaker) => ({
        ...this.parseSpeakerName(speaker.name),
        email: speaker.email,
        jobTitle: speaker.jobTitle,
        bio: speaker.bio,
        isPrimary: speaker.isPrimary,
        speakerTypeLabel: speaker.isPrimary ? "Primary Speaker" : "Co-Speaker",
        contactId: speaker.contactId,
        duplicates: speaker.duplicates || [],
        buttonLabel: speaker.contactId ? "Update Contact" : "Create Contact",
        error: null,
        converting: false
      }));
    } catch (error) {
      this.showErrorToast("Error loading speakers: " + (error.body?.message || error.message));
    } finally {
      this.loading = false;
    }
  }

  parseSpeakerName(fullName) {
    if (!fullName) {
      return { firstName: "", lastName: "" };
    }

    const parts = fullName.trim().split(" ");
    if (parts.length === 1) {
      return { firstName: "", lastName: parts[0] };
    }

    const lastName = parts.pop();
    const firstName = parts.join(" ");
    return { firstName, lastName };
  }

  handleFieldChange(event) {
    const index = parseInt(event.target.dataset.index, 10);
    const field = event.target.dataset.field;
    const value = event.target.value;

    this.speakers = this.speakers.map((speaker, idx) => {
      if (idx === index) {
        return { ...speaker, [field]: value, error: null };
      }
      return speaker;
    });
  }

  get hasSpeakers() {
    return this.speakers && this.speakers.length > 0;
  }

  get allContactsLinked() {
    return this.hasSpeakers && this.speakers.every((speaker) => speaker.contactId);
  }

  get showIndividualButtons() {
    return !this.allContactsLinked;
  }

  get isUpdateAllDisabled() {
    if (!this.hasSpeakers) return true;
    return this.speakers.some((speaker) => speaker.converting || !speaker.firstName || !speaker.lastName || !speaker.email);
  }

  async handleUpdateAll() {
    // Validate all speakers
    for (let i = 0; i < this.speakers.length; i++) {
      const speaker = this.speakers[i];
      if (!speaker.firstName || !speaker.lastName || !speaker.email) {
        this.updateSpeaker(i, { error: "Please fill in all required fields (First Name, Last Name, Email)" });
        return;
      }
    }

    // Update all speakers in parallel
    try {
      const updatePromises = this.speakers.map((speaker, index) => this.convertSpeakerAtIndex(index));
      await Promise.all(updatePromises);
      this.showSuccessToast("All contacts updated successfully");
      this.dispatchEvent(new CustomEvent("convert"));
    } catch {
      // Individual errors are already handled in convertSpeakerAtIndex
    }
  }

  async handleConvertSpeaker(event) {
    const index = parseInt(event.target.dataset.index, 10);
    await this.convertSpeakerAtIndex(index);
  }

  async convertSpeakerAtIndex(index) {
    const speaker = this.speakers[index];

    // Validate required fields
    if (!speaker.firstName || !speaker.lastName || !speaker.email) {
      this.updateSpeaker(index, { error: "Please fill in all required fields (First Name, Last Name, Email)" });
      return;
    }

    // Mark speaker as converting
    this.updateSpeaker(index, { converting: true, error: null });

    try {
      const speakerData = {
        firstName: speaker.firstName,
        lastName: speaker.lastName,
        email: speaker.email,
        jobTitle: speaker.jobTitle || "",
        bio: speaker.bio || ""
      };

      const contactId = await convertSpeakerToContact({
        sessionId: this.sessionId,
        speakerPayload: {
          firstName: speakerData.firstName,
          lastName: speakerData.lastName,
          email: speakerData.email,
          jobTitle: speakerData.jobTitle,
          bio: speakerData.bio,
          isPrimary: speaker.isPrimary,
          existingContactId: speaker.contactId
        }
      });

      this.updateSpeaker(index, { contactId: contactId, converting: false });
      const action = speaker.contactId ? "updated" : "created";
      this.showSuccessToast(`${speaker.speakerTypeLabel} ${action} successfully`);

      // Check if all speakers are converted (only for individual operations)
      if (!this.allContactsLinked && this.allSpeakersConverted()) {
        this.dispatchEvent(new CustomEvent("convert"));
      }
    } catch (error) {
      const errorMessage = error.body?.message || error.message;
      this.updateSpeaker(index, {
        error: errorMessage,
        converting: false
      });
      this.showErrorToast(`Error converting ${speaker.speakerTypeLabel}: ` + errorMessage);
    }
  }

  updateSpeaker(index, updates) {
    this.speakers = this.speakers.map((speaker, idx) => {
      if (idx === index) {
        const updated = { ...speaker, ...updates };
        // Recompute isConvertDisabled and button label
        updated.isConvertDisabled = updated.converting || !updated.firstName || !updated.lastName || !updated.email;
        updated.buttonLabel = updated.contactId ? "Update Contact" : "Create Contact";
        return updated;
      }
      return speaker;
    });
  }

  async handleLinkDuplicate(event) {
    const index = parseInt(event.target.dataset.index, 10);
    const contactId = event.target.dataset.contactid;
    const speaker = this.speakers[index];
    if (!contactId) return;
    this.updateSpeaker(index, { converting: true, error: null });
    try {
      await linkSessionSpeakerToContact({
        sessionId: this.sessionId,
        contactId: contactId,
        isPrimary: speaker.isPrimary
      });
      // Reload speakers to get refreshed data (including removed duplicates list now that it's linked)
      await this.loadSpeakers();
      this.showSuccessToast(`${speaker.speakerTypeLabel} linked to existing Contact`);
    } catch (error) {
      const errorMessage = error.body?.message || error.message;
      this.updateSpeaker(index, { error: errorMessage, converting: false });
      this.showErrorToast(`Error linking ${speaker.speakerTypeLabel}: ` + errorMessage);
    }
  }

  allSpeakersConverted() {
    return this.speakers.every((speaker) => speaker.contactId);
  }

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

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }
}
