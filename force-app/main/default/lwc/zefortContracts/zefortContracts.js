import { LightningElement, api, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getContractsForParty from "@salesforce/apex/ZefortAPI.getContractsForParty";
import createParty from "@salesforce/apex/ZefortAPI.createParty";
import hasApiKey from "@salesforce/apex/ZefortAuthService.hasApiKey";
import getCurrentUiBaseUrl from "@salesforce/apex/ZefortService.getCurrentUiBaseUrl";
import { refreshApex } from "@salesforce/apex";

export default class ZefortContracts extends LightningElement {
  @api recordId; // Account Id
  @track contracts = [];
  @track error;
  @track isLoading = false;
  @track hasZefortApiKey = false;
  @track partyExists = false;
  @track zefortBaseUrl = "https://sandbox.zefort.com"; // Default to sandbox
  wiredContractsResult;

  columns = [
    {
      label: "Name",
      fieldName: "zefortUrl",
      type: "url",
      typeAttributes: {
        label: { fieldName: "title" },
        target: "_blank",
      },
    },
    { label: "Status", fieldName: "status", type: "text" },
    { label: "Created Date", fieldName: "receive_time", type: "date" },
  ];

  async connectedCallback() {
    await this.checkApiKey();
    await this.updateZefortBaseUrl();
  }

  async updateZefortBaseUrl() {
    try {
      this.zefortBaseUrl = await getCurrentUiBaseUrl();
      if (this.contracts.length > 0) {
        this.contracts = this.contracts.map((contract) => ({
          ...contract,
          zefortUrl: `${this.zefortBaseUrl}/contracts/${contract.id}/`,
        }));
      }
    } catch {
      // Keep the default URL if there's an error
    }
  }

  async checkApiKey() {
    try {
      this.hasZefortApiKey = await hasApiKey();
      if (!this.hasZefortApiKey) {
        this.error = "Please configure your Zefort API key in settings";
        this.showToast("Warning", this.error, "warning");
      }
    } catch {
      this.showToast("Error", "Error checking API key", "error");
    }
  }

  handleApiKeySaved() {
    this.checkApiKey();
    if (this.recordId) {
      refreshApex(this.wiredContractsResult);
    }
  }

  @wire(getContractsForParty, { partyId: "$recordId" })
  wiredContracts(result) {
    this.wiredContractsResult = result;
    this.isLoading = false;

    if (result.data) {
      if (result.data.message === "Party not found in Zefort") {
        this.contracts = [];
        this.partyExists = false;
        this.error = result.data.message;
      } else {
        this.partyExists = true;
        if (result.data.results && result.data.results.length > 0) {
          this.contracts = result.data.results.map((contract) => ({
            ...contract,
            title: contract.attributes?.title || "Untitled Contract",
            status: contract.status,
            receive_time: contract.receive_time,
            zefortUrl: `${this.zefortBaseUrl}/contracts/${contract.id}/`,
          }));
          this.error = undefined;
        } else {
          this.contracts = [];
          this.error = undefined;
        }
      }
    } else if (result.error) {
      this.error = result.error.body?.message || "Error fetching contracts";
      this.contracts = [];
      this.partyExists = false;
    }
  }

  get showCreatePartyButton() {
    return this.hasZefortApiKey && !this.partyExists && !this.isLoading;
  }

  get showContractsList() {
    return (
      this.hasZefortApiKey && this.partyExists && this.contracts.length > 0
    );
  }

  get showNoContractsMessage() {
    return (
      this.hasZefortApiKey && this.partyExists && this.contracts.length === 0
    );
  }

  async handleCreateParty() {
    if (!this.recordId) {
      this.showToast("Error", "No Account ID available", "error");
      return;
    }

    if (!this.hasZefortApiKey) {
      this.showToast(
        "Warning",
        "Please configure your Zefort API key in settings",
        "warning",
      );
      return;
    }

    this.isLoading = true;
    try {
      const result = await createParty({ accountId: this.recordId });

      if (result && result.id) {
        this.showToast("Success", "Party created in Zefort", "success");
        this.error = undefined;
        if (this.wiredContractsResult) {
          await refreshApex(this.wiredContractsResult);
        }
      } else {
        throw new Error("Invalid response from server");
      }
    } catch (error) {
      const errorMessage =
        error.body?.message || error.message || JSON.stringify(error);
      this.showToast(
        "Error",
        `Failed to create party: ${errorMessage}`,
        "error",
      );
    } finally {
      this.isLoading = false;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant,
      }),
    );
  }
}