import { LightningElement, api, wire } from "lwc";
import getEvaluationProgress from "@salesforce/apex/CampaignSessionController.getEvaluationProgress";

/**
 * @description Component to display evaluation progress summary for a campaign
 * Shows a banner with overall status and expandable table with per-evaluator details
 * Can be used standalone on Campaign record pages or embedded with data passed via attribute
 */
export default class EvaluationProgressSummary extends LightningElement {
  @api recordId; // Campaign Id when used on record page
  @api evaluationProgress = []; // Data passed from parent component

  _wiredProgress = [];
  showDetails = false;

  // Wire evaluation progress when recordId is provided (standalone mode)
  @wire(getEvaluationProgress, { campaignId: "$recordId" })
  wiredEvaluationProgress({ error, data }) {
    if (data) {
      this._wiredProgress = data;
    } else if (error) {
      console.error("Error loading evaluation progress:", error);
      this._wiredProgress = [];
    }
  }

  // Use wired data if recordId is set, otherwise use passed evaluationProgress
  get effectiveProgress() {
    return this.recordId ? this._wiredProgress : this.evaluationProgress;
  }

  // Computed properties
  get hasEvaluationProgress() {
    return this.effectiveProgress && this.effectiveProgress.length > 0;
  }

  get allEvaluationsComplete() {
    return this.hasEvaluationProgress && this.effectiveProgress.every((run) => run.isComplete);
  }

  get incompleteEvaluationsCount() {
    if (!this.hasEvaluationProgress) return 0;
    return this.effectiveProgress.filter((run) => !run.isComplete).length;
  }

  get summaryMessage() {
    if (!this.hasEvaluationProgress) return "No evaluator runs found";
    if (this.allEvaluationsComplete) return "All evaluations complete";
    return `${this.incompleteEvaluationsCount} of ${this.effectiveProgress.length} evaluations pending`;
  }

  get bannerClass() {
    const base = "slds-box slds-grid slds-grid_vertical-align-center";
    return this.allEvaluationsComplete ? `${base} slds-theme_success` : `${base} slds-theme_warning`;
  }

  get bannerIcon() {
    return this.allEvaluationsComplete ? "utility:success" : "utility:warning";
  }

  get toggleLabel() {
    return this.showDetails ? "Hide Details" : "Show Details";
  }

  get toggleIcon() {
    return this.showDetails ? "utility:chevronup" : "utility:chevrondown";
  }

  get formattedProgress() {
    return this.effectiveProgress.map((run) => ({
      ...run,
      formattedPercent: `${Math.round(run.percentComplete)}%`,
      formattedDate: this.formatDate(run.lastModifiedDate),
      progressVariant: run.isComplete ? "success" : run.percentComplete >= 50 ? "warning" : "base",
      statusBadgeClass: run.isComplete ? "slds-badge slds-theme_success" : "slds-badge slds-theme_warning"
    }));
  }

  // Format date helper
  formatDate(dateValue) {
    if (!dateValue) return "N/A";
    const date = new Date(dateValue);
    return date.toLocaleDateString(undefined, {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit"
    });
  }

  // Toggle details visibility
  handleToggle() {
    this.showDetails = !this.showDetails;
  }
}
