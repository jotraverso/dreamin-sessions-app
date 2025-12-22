import { LightningElement, api, track } from "lwc";

export default class SessionItem extends LightningElement {
  @api session;
  @api categories = [];
  @api selectedCount = 0;
  @api reserveCount = 0;
  @api maxSelected = 0;
  @api maxReserve = 0;

  @track currentMainCategory;

  connectedCallback() {
    this.currentMainCategory = this.session.mainCategory || this.defaultMainCategory;
  }

  get selectionState() {
    const status = this.session.selectionStatus || "Not Selected";
    if (status === "Selected") return "selected";
    if (status === "Reserve") return "reserve";
    return "none";
  }

  get durationLabel() {
    return `${this.session.duration || 0} min`;
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

  get defaultMainCategory() {
    if (!this.session.category) return null;
    const categories = this.session.category.split(";");
    return categories[0] || null;
  }

  get categoryOptions() {
    // Use the full category picklist from parent, not just session categories
    return this.categories || [];
  }

  get selectionButtonLabel() {
    switch (this.selectionState) {
      case "selected":
        return "Reserve";
      case "reserve":
        return "Deselect";
      default:
        return "Select";
    }
  }

  get selectionButtonVariant() {
    switch (this.selectionState) {
      case "selected":
        // Button will move to Reserve (orange)
        return "destructive-text";
      case "reserve":
        // Button will deselect (red)
        return "destructive";
      default:
        // Check if selecting would auto-toggle to reserve
        if (this.selectedCount >= this.maxSelected && this.reserveCount < this.maxReserve) {
          return "warning"; // Orange for reserve
        }
        return "success"; // Green for select
    }
  }

  get selectionStatusLabel() {
    switch (this.selectionState) {
      case "selected":
        return "Selected";
      case "reserve":
        return "Reserve";
      default:
        return "Not Selected";
    }
  }

  get selectionStatusClass() {
    switch (this.selectionState) {
      case "selected":
        return "slds-theme_success";
      case "reserve":
        return "slds-theme_warning";
      default:
        return "";
    }
  }

  handleToggleSelection() {
    let newSelectionStatus;
    let isAutoToggle = false;
    const currentState = this.selectionState;
    console.log("Toggle clicked, current state:", currentState);

    switch (currentState) {
      case "none":
        // Check if we can select
        if (this.selectedCount >= this.maxSelected) {
          // Auto-toggle to reserve if reserve has space
          if (this.reserveCount < this.maxReserve) {
            newSelectionStatus = "Reserve";
            isAutoToggle = true;
            this.showToast("Warning", `Selected limit reached (${this.maxSelected}). Session marked as Reserve instead.`, "warning");
          } else {
            // Both limits reached, show error
            this.showToast(
              "Error",
              `Cannot select or reserve. Both limits reached (Selected: ${this.maxSelected}, Reserve: ${this.maxReserve})`,
              "error"
            );
            return;
          }
        } else {
          newSelectionStatus = "Selected";
        }
        break;
      case "selected":
        newSelectionStatus = "Reserve";
        break;
      case "reserve":
        newSelectionStatus = "Not Selected";
        break;
      default:
        newSelectionStatus = "Not Selected";
    }

    console.log("New selection status:", newSelectionStatus);

    // Don't mutate session directly, just dispatch the event
    // The parent will update the session object
    this.dispatchSelectionChange(newSelectionStatus, isAutoToggle);
  }

  handleMainCategoryChange(event) {
    this.currentMainCategory = event.detail.value;
    this.dispatchSelectionChange(this.session.selectionStatus || "Not Selected", false);
  }

  dispatchSelectionChange(selectionStatus, isAutoToggle = false) {
    const detail = {
      sessionId: this.session.id,
      selectionStatus: selectionStatus,
      mainCategory: this.currentMainCategory,
      isAutoToggle: isAutoToggle
    };
    this.dispatchEvent(new CustomEvent("selectionchange", { detail }));
  }

  showToast(title, message, variant) {
    const event = new CustomEvent("showtoast", {
      detail: { title, message, variant },
      bubbles: true,
      composed: true
    });
    this.dispatchEvent(event);
  }

  handleViewDetails() {
    this.dispatchEvent(
      new CustomEvent("viewdetails", {
        detail: { sessionId: this.session.id }
      })
    );
  }

  handleConvertSpeakers() {
    this.dispatchEvent(
      new CustomEvent("convertspeakers", {
        detail: { sessionId: this.session.id }
      })
    );
  }
}
