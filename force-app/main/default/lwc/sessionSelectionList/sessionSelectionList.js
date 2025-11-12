import { LightningElement, api, track } from "lwc";

export default class SessionSelectionList extends LightningElement {
  @api sessions = [];
  @api categories = [];
  @api selectedCount = 0;
  @api reserveCount = 0;
  @api maxSelected = 0;
  @api maxReserve = 0;

  @track categoryFilter = "";
  @track languageFilter = "";

  get displayedSessions() {
    let filtered = [...this.sessions];

    if (this.categoryFilter) {
      filtered = filtered.filter(
        (session) => session.mainCategory === this.categoryFilter || (session.category && session.category.includes(this.categoryFilter))
      );
    }

    if (this.languageFilter) {
      filtered = filtered.filter((session) => session.language === this.languageFilter);
    }

    return filtered;
  }

  get hasSessions() {
    return this.displayedSessions && this.displayedSessions.length > 0;
  }

  get categoryFilterOptions() {
    const uniqueCategories = new Set();
    this.sessions.forEach((session) => {
      if (session.category) {
        session.category.split(";").forEach((cat) => uniqueCategories.add(cat.trim()));
      }
    });

    const options = [{ label: "All Categories", value: "" }];
    uniqueCategories.forEach((cat) => {
      options.push({ label: cat, value: cat });
    });

    return options;
  }

  get languageFilterOptions() {
    const uniqueLanguages = new Set();
    this.sessions.forEach((session) => {
      if (session.language) {
        uniqueLanguages.add(session.language);
      }
    });

    const options = [{ label: "All Languages", value: "" }];
    uniqueLanguages.forEach((lang) => {
      options.push({ label: lang, value: lang });
    });

    return options;
  }

  handleCategoryFilterChange(event) {
    this.categoryFilter = event.detail.value;
  }

  handleLanguageFilterChange(event) {
    this.languageFilter = event.detail.value;
  }

  handleSelectionChange(event) {
    this.dispatchEvent(new CustomEvent("selectionchange", { detail: event.detail }));
  }

  handleViewDetails(event) {
    this.dispatchEvent(new CustomEvent("viewdetails", { detail: event.detail }));
  }

  handleConvertSpeakers(event) {
    this.dispatchEvent(new CustomEvent("convertspeakers", { detail: event.detail }));
  }
}
