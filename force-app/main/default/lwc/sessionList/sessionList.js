import { LightningElement, track, api, wire } from "lwc";
import getSessionEvaluations from "@salesforce/apex/SessionEvaluationService.getSessionEvaluations";
import updateEvaluationScores from "@salesforce/apex/SessionEvaluationService.updateEvaluationScores";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { RefreshEvent } from "lightning/refresh";
import { publish, MessageContext } from "lightning/messageService";
import { reduceErrors } from "c/errorUtils";
import EVALUATION_PROGRESS_CHANNEL from "@salesforce/messageChannel/EvaluationProgressChannel__c";

export default class SessionList extends LightningElement {
  @api recordId; // EvaluatorRun record ID when on record page

  @track allEvaluations = [];
  @track currentIndex = 0;
  @track error;
  @track loading = false;
  @track showNonSubmittedOnly = true; // Default to filtering non-submitted only
  @track transitionClass = "";
  @track _layoutVersion = 0; // used to force rerender on resize

  // Touch/swipe handling
  touchStartX = 0;
  touchEndX = 0;
  touchStartY = 0;
  touchEndY = 0;

  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    this.loadEvaluations();
    // Listen for resize to update button labels responsively
    this._resizeHandler = () => {
      // Increment dummy counter to force re-render for responsive labels
      this._layoutVersion++;
    };
    window.addEventListener("resize", this._resizeHandler);
  }

  disconnectedCallback() {
    if (this._resizeHandler) {
      window.removeEventListener("resize", this._resizeHandler);
    }
  }

  loadEvaluations() {
    this.loading = true;
    this.error = undefined;

    getSessionEvaluations({ runId: this.recordId })
      .then((result) => {
        this.allEvaluations = result || [];
        this.currentIndex = this.evaluations.length > 0 ? 1 : 0;
        this.error = undefined;
      })
      .catch((error) => {
        const messages = reduceErrors(error);
        const message =
          messages.length > 0
            ? messages.join("\n")
            : "Error loading evaluations";
        this.error = message;
        this.allEvaluations = [];
        // Show toast on error
        const errorEvent = new ShowToastEvent({
          title: "Error",
          message,
          variant: "error"
        });
        this.dispatchEvent(errorEvent);
      })
      .finally(() => {
        this.loading = false;
      });
  }

  get evaluations() {
    if (!this.allEvaluations || this.allEvaluations.length === 0) {
      return [];
    }

    // Filter based on showNonSubmittedOnly toggle
    if (this.showNonSubmittedOnly) {
      // Show only non-submitted evaluations (Status !== 'Submitted')
      return this.allEvaluations.filter(
        (evaluation) => evaluation.Status__c !== "Submitted"
      );
    }

    // Show all evaluations
    return this.allEvaluations;
  }

  get filterDescription() {
    if (this.showNonSubmittedOnly) {
      return `Showing non-submitted evaluations (${this.evaluations.length} of ${this.allEvaluations.length})`;
    }

    return `Showing all evaluations (${this.evaluations.length})`;
  }

  get hasEvaluations() {
    return this.evaluations && this.evaluations.length > 0;
  }

  get currentEvaluation() {
    if (!this.hasEvaluations) {
      return null;
    }
    return this.evaluations[this.currentIndex - 1];
  }

  get totalEvaluations() {
    return this.evaluations.length;
  }

  get isFirstEvaluation() {
    return this.currentIndex <= 1;
  }

  get isLastEvaluation() {
    return this.currentIndex >= this.totalEvaluations;
  }

  get flagButtonLabel() {
    return this.currentEvaluation?.Flagged__c ? "Unflag" : "Flag";
  }

  get flagButtonVariant() {
    return this.currentEvaluation?.Flagged__c ? "destructive" : "neutral";
  }

  // Responsive button labels: compact on narrow widths
  get isCompactLayout() {
    return window.innerWidth <= 520; // threshold can be tuned
  }
  get previousButtonLabel() {
    return this.isCompactLayout ? "<" : "Previous";
  }
  get nextButtonLabel() {
    return this.isCompactLayout ? ">" : "Next";
  }

  handlePrevious() {
    if (!this.isFirstEvaluation) {
      this.applySlide();
      this.currentIndex--;
    }
  }

  handleNext() {
    if (!this.isLastEvaluation) {
      this.applySlide();
      this.currentIndex++;
    }
  }

  handleToggleFilter(event) {
    this.showNonSubmittedOnly = event.target.checked;
    // Reset to first evaluation when filter changes
    this.currentIndex = this.evaluations.length > 0 ? 1 : 0;
  }

  handleFlag() {
    if (!this.currentEvaluation) {
      return;
    }

    const newFlaggedState = !this.currentEvaluation.Flagged__c;

    // Update the evaluation with current scores and toggle flag
    const formComponent = this.template.querySelector("c-evaluation-form");
    if (!formComponent) {
      this.showToast("Error", "Could not find evaluation form", "error");
      return;
    }

    const formData = formComponent.getFormData();

    updateEvaluationScores({
      evaluationId: this.currentEvaluation.Id,
      clarity: formData.clarity,
      diversity: formData.diversity,
      engagement: formData.engagement,
      comments: formData.comments,
      flagged: newFlaggedState
    })
      .then(() => {
        // Update local state
        this.currentEvaluation.Flagged__c = newFlaggedState;
        this.showToast(
          "Success",
          `Session ${newFlaggedState ? "flagged" : "unflagged"} successfully`,
          "success"
        );

        // Publish message to update progress
        this.publishProgressUpdate();
      })
      .catch((error) => {
        const messages = reduceErrors(error);
        const message =
          messages.length > 0
            ? messages.join("\n")
            : "Error updating flag status";
        if (
          formComponent &&
          typeof formComponent.showServerError === "function"
        ) {
          formComponent.showServerError(message);
        }
        this.error = message;
        this.showToast("Error", message, "error");
      });
  }

  handleSubmit() {
    const formComponent = this.template.querySelector("c-evaluation-form");

    if (!formComponent) {
      this.showToast("Error", "Could not find evaluation form", "error");
      return;
    }

    // Validate form
    if (!formComponent.validateForm()) {
      return;
    }

    const formData = formComponent.getFormData();

    updateEvaluationScores({
      evaluationId: this.currentEvaluation.Id,
      clarity: formData.clarity,
      diversity: formData.diversity,
      engagement: formData.engagement,
      comments: formData.comments,
      flagged: this.currentEvaluation.Flagged__c || false
    })
      .then(() => {
        this.showToast(
          "Success",
          "Evaluation scores submitted successfully",
          "success"
        );

        // Update local record
        this.currentEvaluation.ClarityScore__c = formData.clarity;
        this.currentEvaluation.DiversityScore__c = formData.diversity;
        this.currentEvaluation.EngagementScore__c = formData.engagement;
        this.currentEvaluation.Comments__c = formData.comments;
        this.currentEvaluation.Status__c = "Submitted";

        // Refresh the page
        this.dispatchEvent(new RefreshEvent());

        // Publish message to update progress
        this.publishProgressUpdate();

        // Move to next if available
        if (!this.isLastEvaluation) {
          this.handleNext();
        }
      })
      .catch((error) => {
        const messages = reduceErrors(error);
        const message =
          messages.length > 0
            ? messages.join("\n")
            : "Error submitting evaluation";
        if (
          formComponent &&
          typeof formComponent.showServerError === "function"
        ) {
          formComponent.showServerError(message);
        }
        this.error = message;
        this.showToast("Error", message, "error");
      });
  }

  publishProgressUpdate() {
    const message = {
      evaluationUpdated: true,
      runId: this.recordId
    };
    publish(this.messageContext, EVALUATION_PROGRESS_CHANNEL, message);
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }

  // Touch event handlers for swipe navigation
  handleTouchStart(event) {
    this.touchStartX = event.changedTouches[0].screenX;
    this.touchStartY = event.changedTouches[0].screenY;
  }

  handleTouchMove(event) {
    this.touchEndX = event.changedTouches[0].screenX;
    this.touchEndY = event.changedTouches[0].screenY;
  }

  handleTouchEnd() {
    const swipeThreshold = 50; // minimum distance for swipe
    const deltaX = this.touchEndX - this.touchStartX;
    const deltaY = Math.abs(this.touchEndY - this.touchStartY);

    // Only trigger swipe if horizontal movement is greater than vertical
    // This prevents interfering with vertical scrolling
    if (Math.abs(deltaX) > deltaY && Math.abs(deltaX) > swipeThreshold) {
      if (deltaX > 0) {
        // Swipe right - go to previous
        if (!this.isFirstEvaluation) {
          this.applySlide();
          this.handlePrevious();
        }
      } else {
        // Swipe left - go to next
        if (!this.isLastEvaluation) {
          this.applySlide();
          this.handleNext();
        }
      }
    }

    // Reset values
    this.touchStartX = 0;
    this.touchEndX = 0;
    this.touchStartY = 0;
    this.touchEndY = 0;
  }

  applySlide() {
    // Fade-in only animation; we restart it by clearing and re-applying class
    this.transitionClass = "";
    // eslint-disable-next-line no-unused-expressions
    this.offsetHeight; // reflow
    this.transitionClass = "fade-in";
    const container = this.template.querySelector(".swipe-container");
    if (container) {
      const handler = () => {
        this.transitionClass = "";
        container.removeEventListener("animationend", handler);
      };
      container.addEventListener("animationend", handler);
    }
  }
}
