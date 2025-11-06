import { LightningElement, api, track } from "lwc";
import submitEvaluationWithData from "@salesforce/apex/SessionEvaluationService.submitEvaluationWithData";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class EvaluationForm extends LightningElement {
  @api sessionId;
  @api session; // Full session object passed from parent

  @track clarity = 0;
  @track diversity = 0;
  @track engagement = 0;
  @track comments = "";
  @track error;

  handleInput(event) {
    const name = event.target.name;
    const value = event.target.value;

    if (name === "clarity") {
      this.clarity = value;
    } else if (name === "diversity") {
      this.diversity = value;
    } else if (name === "engagement") {
      this.engagement = value;
    } else if (name === "comments") {
      this.comments = value;
    }
  }

  handleSubmit() {
    // Validate scores
    if (!this.clarity || !this.diversity || !this.engagement) {
      this.error = "Please provide all required scores";
      return;
    }

    const payload = {
      sessionId: this.sessionId,
      clarity: Number(this.clarity),
      diversity: Number(this.diversity),
      engagement: Number(this.engagement),
      comments: this.comments
    };

    submitEvaluationWithData({ inputJson: JSON.stringify(payload) })
      .then(() => {
        this.showToast(
          "Success",
          "Evaluation submitted successfully",
          "success"
        );
        this.dispatchEvent(new CustomEvent("success"));
        this.resetForm();
      })
      .catch((error) => {
        this.error = error.body?.message || "An error occurred";
        this.showToast("Error", this.error, "error");
      });
  }

  resetForm() {
    this.clarity = 0;
    this.diversity = 0;
    this.engagement = 0;
    this.comments = "";
    this.error = undefined;
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }
}
