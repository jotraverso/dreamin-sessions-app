import { LightningElement, api } from "lwc";

export default class SessionDetailsModal extends LightningElement {
  @api session;

  connectedCallback() {
    // Add ESC key listener
    window.addEventListener("keydown", this.handleKeyDownEvent);
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

  get durationLabel() {
    return `${this.session.duration || 0} minutes`;
  }

  get finalScoreDisplay() {
    return this.session.finalScore ? Number(this.session.finalScore).toFixed(2) : "0.00";
  }

  get clarityDisplay() {
    return this.session.clarityAvg ? Number(this.session.clarityAvg).toFixed(2) : "0.00";
  }

  get contentDisplay() {
    return this.session.contentAvg ? Number(this.session.contentAvg).toFixed(2) : "0.00";
  }

  get engagementDisplay() {
    return this.session.engagementAvg ? Number(this.session.engagementAvg).toFixed(2) : "0.00";
  }

  get categoriesDisplay() {
    return this.session.category ? this.session.category.replace(/;/g, ", ") : "None";
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }
}
