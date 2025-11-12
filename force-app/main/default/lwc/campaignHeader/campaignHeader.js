import { LightningElement, api } from "lwc";

export default class CampaignHeader extends LightningElement {
  @api campaign;
  @api selectedCount;
  @api reserveCount;
  @api hasRecordId = false;

  get hasCampaign() {
    return this.campaign && this.campaign.name;
  }

  get maxSelectedLabel() {
    return `${this.campaign.maxSelectedSessions || 0}`;
  }

  get maxReserveLabel() {
    return `${this.campaign.maxReserveSessions || 0}`;
  }

  get selectedLabel() {
    return `${this.selectedCount || 0}`;
  }

  get reserveLabel() {
    return `${this.reserveCount || 0}`;
  }

  get selectedBadgeClass() {
    if (this.selectedCount > this.campaign.maxSelectedSessions) {
      return "slds-theme_error";
    } else if (this.selectedCount === this.campaign.maxSelectedSessions) {
      return "slds-theme_warning";
    }
    return "slds-theme_success";
  }

  get reserveBadgeClass() {
    if (this.reserveCount > this.campaign.maxReserveSessions) {
      return "slds-theme_error";
    } else if (this.reserveCount === this.campaign.maxReserveSessions) {
      return "slds-theme_warning";
    }
    return "slds-theme_success";
  }

  handleCampaignChange(event) {
    const campaignId = event.detail.recordId;
    this.dispatchEvent(
      new CustomEvent("campaignchange", {
        detail: { campaignId }
      })
    );
  }
}
