import { LightningElement, api, track, wire } from "lwc";
import getEvaluatorProgressByRun from "@salesforce/apex/SessionEvaluationService.getEvaluatorProgressByRun";
import { refreshApex } from "@salesforce/apex";
import {
  subscribe,
  unsubscribe,
  MessageContext
} from "lightning/messageService";
import EVALUATION_PROGRESS_CHANNEL from "@salesforce/messageChannel/EvaluationProgressChannel__c";

export default class SessionQueuePanel extends LightningElement {
  @api recordId; // EvaluatorRun record ID when on record page
  @api campaignId; // Deprecated - use recordId instead

  @track progress;
  @track error;
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
    } else if (result.error) {
      this.error = result.error.body?.message || "Error loading progress";
      this.progress = undefined;
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
      this.subscription = subscribe(
        this.messageContext,
        EVALUATION_PROGRESS_CHANNEL,
        (message) => this.handleProgressMessage(message)
      );
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
    return this.progress?.percentComplete
      ? Math.round(this.progress.percentComplete)
      : 0;
  }

  get isComplete() {
    return this.progress?.submittedCount >= this.progress?.targetCount;
  }

  handleFinalize() {
    // Dispatch event to parent component to handle finalization
    this.dispatchEvent(
      new CustomEvent("finalize", {
        detail: { runId: this.progress.runId }
      })
    );
  }

  @api
  refresh() {
    return refreshApex(this.wiredProgressResult);
  }
}
