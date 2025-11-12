import { LightningElement, api, wire } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import chartjs from "@salesforce/resourceUrl/chartjs_450";
import getCampaignDetails from "@salesforce/apex/CampaignSessionController.getCampaignDetails";
import getSessions from "@salesforce/apex/CampaignSessionController.getSessions";

export default class SelectionSummary extends LightningElement {
  @api recordId; // Campaign Id when used on record page
  @api selectedCount;
  @api reserveCount;
  @api maxSelected;
  @api maxReserve;
  @api categoryStats;
  @api languageStats;

  chartjsInitialized = false;
  categoryChart;
  languageChart;

  // Internal data when used on record page
  _campaign = {};
  _sessions = [];

  // Wire campaign details when recordId is available
  @wire(getCampaignDetails, { campaignId: "$recordId" })
  wiredCampaign({ data }) {
    if (data && this.recordId) {
      this._campaign = data;
    }
  }

  // Wire sessions when recordId is available
  @wire(getSessions, { campaignId: "$recordId" })
  wiredSessions({ data }) {
    if (data && this.recordId) {
      this._sessions = data;
    }
  }

  // Use passed props or compute from wired data
  get effectiveSelectedCount() {
    if (this.recordId) {
      return this._sessions.filter((s) => s.selectionStatus === "Selected").length;
    }
    return this.selectedCount || 0;
  }

  get effectiveReserveCount() {
    if (this.recordId) {
      return this._sessions.filter((s) => s.selectionStatus === "Reserve").length;
    }
    return this.reserveCount || 0;
  }

  get effectiveMaxSelected() {
    if (this.recordId) {
      return this._campaign.maxSelectedSessions || 0;
    }
    return this.maxSelected || 0;
  }

  get effectiveMaxReserve() {
    if (this.recordId) {
      return this._campaign.maxReserveSessions || 0;
    }
    return this.maxReserve || 0;
  }

  get effectiveCategoryStats() {
    if (this.recordId) {
      const stats = {};
      this._sessions
        .filter((s) => s.selectionStatus === "Selected")
        .forEach((session) => {
          const cat = session.mainCategory || "Uncategorized";
          stats[cat] = (stats[cat] || 0) + 1;
        });
      return Object.entries(stats).map(([label, value]) => ({ label, value }));
    }
    return this.categoryStats || [];
  }

  get effectiveLanguageStats() {
    if (this.recordId) {
      const stats = {};
      this._sessions
        .filter((s) => s.selectionStatus === "Selected")
        .forEach((session) => {
          const lang = session.language || "Unknown";
          stats[lang] = (stats[lang] || 0) + 1;
        });
      return Object.entries(stats).map(([label, value]) => ({ label, value }));
    }
    return this.languageStats || [];
  }

  renderedCallback() {
    if (this.chartjsInitialized) {
      this.updateCharts();
      return;
    }

    this.loadChartJs();
  }

  loadChartJs() {
    loadScript(this, chartjs)
      .then(() => {
        this.chartjsInitialized = true;
        // Chart.js v4 is available as window.Chart after loading
        console.log("Chart.js loaded:", typeof window.Chart);
        this.initializeCharts();
      })
      .catch((error) => {
        console.error("Error loading Chart.js", error);
      });
  }

  initializeCharts() {
    if (this.hasCategoryStats) {
      this.renderCategoryChart();
    }
    if (this.hasLanguageStats) {
      this.renderLanguageChart();
    }
  }

  updateCharts() {
    if (this.categoryChart) {
      this.categoryChart.destroy();
    }
    if (this.languageChart) {
      this.languageChart.destroy();
    }

    if (this.hasCategoryStats) {
      this.renderCategoryChart();
    }
    if (this.hasLanguageStats) {
      this.renderLanguageChart();
    }
  }

  renderCategoryChart() {
    const canvas = this.refs.categoryChart;
    if (!canvas || !window.Chart) {
      console.error("Chart.js not loaded or canvas not found");
      return;
    }

    const ctx = canvas.getContext("2d");
    const data = this.effectiveCategoryStats || [];

    // For Chart.js v4, use window.Chart directly
    const Chart = window.Chart;

    this.categoryChart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.map((stat) => stat.label),
        datasets: [
          {
            label: "Sessions by Category",
            data: data.map((stat) => stat.value),
            backgroundColor: this.generateColors(data.length)
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              stepSize: 1
            }
          }
        }
      }
    });
  }

  renderLanguageChart() {
    const canvas = this.refs.languageChart;
    if (!canvas || !window.Chart) {
      console.error("Chart.js not loaded or canvas not found");
      return;
    }

    const ctx = canvas.getContext("2d");
    const data = this.effectiveLanguageStats || [];

    // For Chart.js v4, use window.Chart directly
    const Chart = window.Chart;

    this.languageChart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.map((stat) => stat.label),
        datasets: [
          {
            label: "Sessions by Language",
            data: data.map((stat) => stat.value),
            backgroundColor: "#1589EE"
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              stepSize: 1
            }
          }
        }
      }
    });
  }

  generateColors(count) {
    const colors = ["#1589EE", "#06A59A", "#E3BC00", "#DD7A01", "#C23934", "#6B5CAE", "#48C3CC", "#8CC152", "#FFB75D", "#FF6C60"];

    const result = [];
    for (let i = 0; i < count; i++) {
      result.push(colors[i % colors.length]);
    }
    return result;
  }

  get selectedCountClass() {
    if (this.effectiveSelectedCount > this.effectiveMaxSelected) {
      return "slds-text-color_error";
    } else if (this.effectiveSelectedCount === this.effectiveMaxSelected) {
      return "slds-text-color_success";
    }
    return "";
  }

  get reserveCountClass() {
    if (this.effectiveReserveCount > this.effectiveMaxReserve) {
      return "slds-text-color_error";
    } else if (this.effectiveReserveCount === this.effectiveMaxReserve) {
      return "slds-text-color_success";
    }
    return "";
  }

  get hasCategoryStats() {
    return this.effectiveCategoryStats && this.effectiveCategoryStats.length > 0;
  }

  get hasLanguageStats() {
    return this.effectiveLanguageStats && this.effectiveLanguageStats.length > 0;
  }

  get hasAnyStats() {
    return this.hasCategoryStats || this.hasLanguageStats;
  }
}
