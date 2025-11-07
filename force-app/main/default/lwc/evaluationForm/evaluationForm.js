import { LightningElement, api, track } from "lwc";

export default class EvaluationForm extends LightningElement {
  @api evaluationId;

  @track clarity = 0;
  @track diversity = 0;
  @track engagement = 0;
  @track comments = "";
  @track error;

  _evaluation;

  @api
  get evaluation() {
    return this._evaluation;
  }

  set evaluation(value) {
    this._evaluation = value;
    if (value) {
      this.loadEvaluationData();
    }
  }

  connectedCallback() {
    if (this._evaluation) {
      this.loadEvaluationData();
    }
  }

  @api
  get sessionInfo() {
    if (!this._evaluation || !this._evaluation.Session__r) {
      return null;
    }

    return {
      title: this._evaluation.Session__r.Title__c,
      abstract: this._evaluation.Session__r.Abstract__c,
      level: this._evaluation.Session__r.Level__c,
      category: this._evaluation.Session__r.Category__c,
      duration: this._evaluation.Session__r.DurationMinutes__c
    };
  }

  loadEvaluationData() {
    this.clarity = this._evaluation.ClarityScore__c || 0;
    this.diversity = this._evaluation.DiversityScore__c || 0;
    this.engagement = this._evaluation.EngagementScore__c || 0;
    this.comments = this._evaluation.Comments__c || "";
  }

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

    // Clear error when user starts typing
    this.error = undefined;
  }

  @api
  getFormData() {
    return {
      clarity: Number(this.clarity),
      diversity: Number(this.diversity),
      engagement: Number(this.engagement),
      comments: this.comments
    };
  }

  @api
  validateForm(skipValidation = false) {
    // Skip validation when flagging (allow 0 scores)
    if (skipValidation) {
      this.error = undefined;
      return true;
    }

    if (!this.clarity || !this.diversity || !this.engagement) {
      this.error = "Please provide all required scores";
      return false;
    }

    if (this.clarity < 1 || this.clarity > 20) {
      this.error = "Clarity score must be between 1 and 20";
      return false;
    }

    if (this.diversity < 1 || this.diversity > 10) {
      this.error = "Diversity score must be between 1 and 10";
      return false;
    }

    if (this.engagement < 1 || this.engagement > 20) {
      this.error = "Engagement score must be between 1 and 20";
      return false;
    }

    this.error = undefined;
    return true;
  }

  @api
  resetForm() {
    this.clarity = 0;
    this.diversity = 0;
    this.engagement = 0;
    this.comments = "";
    this.error = undefined;
  }
}
