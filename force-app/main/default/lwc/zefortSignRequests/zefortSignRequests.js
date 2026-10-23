import { LightningElement, api, track } from "lwc";
import listSignRequests from "@salesforce/apex/ZefortSignService.listSignRequests";
import listSignRequestParties from "@salesforce/apex/ZefortSignService.listSignRequestParties";
import refreshSignRequestsForRecord from "@salesforce/apex/ZefortSignService.refreshSignRequestsForRecord";

export default class ZefortSignRequests extends LightningElement {
  @api recordId;
  @track requests = [];
  @track selectedRequestId;
  @track selectedRequestParties = [];
  @track isLoading = true;
  @track error;

  requestColumns = [
    { label: "Title", fieldName: "title", type: "text" },
    { label: "Status", fieldName: "status", type: "text" },
    {
      label: "Status Saved",
      fieldName: "statusSavedAt",
      type: "date",
      typeAttributes: { year: "numeric", month: "2-digit", day: "2-digit" },
    },
    {
      label: "Last Sync",
      fieldName: "lastSyncedAt",
      type: "date",
      typeAttributes: { year: "numeric", month: "2-digit", day: "2-digit" },
    },
    {
      type: "button",
      typeAttributes: {
        label: "View Parties",
        name: "view_parties",
        variant: "base",
      },
    },
  ];

  partyColumns = [
    { label: "Name", fieldName: "name", type: "text" },
    { label: "Email", fieldName: "email", type: "email" },
    { label: "Role", fieldName: "role", type: "text" },
    { label: "Status", fieldName: "status", type: "text" },
    { label: "Forwarded To", fieldName: "forwardedTo", type: "text" },
  ];

  connectedCallback() {
    this.loadRequests();
  }

  async loadRequests(options = { sync: false }) {
    this.isLoading = true;
    this.error = undefined;
    try {
      if (options.sync) {
        await refreshSignRequestsForRecord({ sourceRecordId: this.recordId });
      }
      this.requests = await listSignRequests({ sourceRecordId: this.recordId });
    } catch (error) {
      this.error =
        error.body?.message || error.message || "Failed to load sign requests.";
    } finally {
      this.isLoading = false;
    }
  }

  async handleRefresh() {
    await this.loadRequests({ sync: true });
  }

  async handleRequestAction(event) {
    const action = event.detail.action;
    const row = event.detail.row;

    if (action.name !== "view_parties") {
      return;
    }

    this.selectedRequestId = row.id;
    this.selectedRequestParties = await listSignRequestParties({
      signRequestId: row.id,
    });
  }

  get hasRequests() {
    return this.requests.length > 0;
  }

  get hasSelectedParties() {
    return this.selectedRequestParties.length > 0;
  }
}