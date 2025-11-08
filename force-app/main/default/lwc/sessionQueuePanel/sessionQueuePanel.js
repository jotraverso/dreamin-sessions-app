import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getEvaluatorProgressByRun from "@salesforce/apex/SessionEvaluationService.getEvaluatorProgressByRun";
import canFinalizeRun from "@salesforce/apex/SessionEvaluationService.canFinalizeRun";
import finalizeRun from "@salesforce/apex/SessionEvaluationService.finalizeRun";
import { refreshApex } from "@salesforce/apex";
import { subscribe, unsubscribe, MessageContext } from "lightning/messageService";
import EVALUATION_PROGRESS_CHANNEL from "@salesforce/messageChannel/EvaluationProgressChannel__c";

export default class SessionQueuePanel extends LightningElement {
  @api recordId; // EvaluatorRun record ID when on record page
  @api campaignId; // Deprecated - use recordId instead

  @track progress;
  @track error;
  @track isFinalized = false;
  @track canFinalize = false;
  @track isProcessing = false;

  wiredProgressResult;
  subscription = null;

  @wire(MessageContext)
  messageContext;
  @wire(getEvaluatorProgressByRun, { runId: "$recordId" })
  wiredProgress(result) {
    this.wiredProgressResult = result;
    if (result.data) {
      this.progress = result.data;
      this.error = undefined;
      this.isFinalized = this.progress.status === "Finalized";

      // Check if run can be finalized
      this.checkCanFinalize();
    } else if (result.error) {
      this.error = result.error.body?.message || "Error loading progress";
      this.progress = undefined;
    }
  }

  async checkCanFinalize() {
    if (!this.recordId) return;

    try {
      this.canFinalize = await canFinalizeRun({ runId: this.recordId });
      console.log("canFinalizeRun result:", this.canFinalize);
      console.log("Progress data:", JSON.stringify(this.progress));
    } catch (error) {
      console.error("Error checking finalize eligibility:", error);
      this.canFinalize = false;
    }
  }

  connectedCallback() {
    this.subscribeToMessageChannel();
  }

  disconnectedCallback() {
    this.unsubscribeFromMessageChannel();
  }

  subscribeToMessageChannel() {
    if (!this.subscription) {
      this.subscription = subscribe(this.messageContext, EVALUATION_PROGRESS_CHANNEL, (message) => this.handleProgressMessage(message));
    }
  }

  unsubscribeFromMessageChannel() {
    unsubscribe(this.subscription);
    this.subscription = null;
  }

  handleProgressMessage(message) {
    // Refresh data when message received
    if (message.evaluationUpdated && message.runId === this.recordId) {
      this.refresh();
    }
  }

  get percentCompleteDisplay() {
    return this.progress?.percentComplete ? Math.round(this.progress.percentComplete) : 0;
  }

  get isComplete() {
    return this.progress?.submittedCount >= this.progress?.targetCount;
  }

  get showFinalizeButton() {
    // Show button if complete and not finalized
    // canFinalize is checked async, so we show the button if complete
    return this.isComplete && !this.isFinalized;
  }

  get finalizeButtonDisabled() {
    // Disable if processing or can't finalize (once we know)
    return this.isProcessing || this.canFinalize === false;
  }

  get statusLabel() {
    if (this.isFinalized) {
      return "Finalized";
    }
    if (this.isComplete) {
      return "Complete - Ready to Finalize";
    }
    return "In Progress";
  }

  get statusVariant() {
    if (this.isFinalized) {
      return "success";
    }
    if (this.isComplete) {
      return "warning";
    }
    return "default";
  }

  async handleFinalize() {
    if (!this.recordId) return;

    this.isProcessing = true;

    try {
      await finalizeRun({ runId: this.recordId });

      // Show success message
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Your evaluation run has been finalized. No further changes can be made.",
          variant: "success"
        })
      );

      // Refresh the progress data
      await this.refresh();

      // Dispatch custom event for parent components
      this.dispatchEvent(
        new CustomEvent("finalized", {
          detail: { runId: this.recordId }
        })
      );
    } catch (error) {
      // Show error message
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error Finalizing Run",
          message: error.body?.message || "An error occurred while finalizing the run",
          variant: "error"
        })
      );
    } finally {
      this.isProcessing = false;
    }
  }

  @api
  refresh() {
    return refreshApex(this.wiredProgressResult);
  }
}
