import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import saveUserApiKey from "@salesforce/apex/ZefortAuthService.saveUserApiKey";
import getApiKeyMask from "@salesforce/apex/ZefortAuthService.getApiKeyMask";
import setRegion from "@salesforce/apex/ZefortRegion.setRegion";
import getRegion from "@salesforce/apex/ZefortRegion.getRegion";
import getInternalSigner from "@salesforce/apex/ZefortSettings.getInternalSigner";
import searchContacts from "@salesforce/apex/ZefortSettings.searchContacts";
import setInternalSigner from "@salesforce/apex/ZefortSettings.setInternalSigner";

export default class ZefortSettings extends LightningElement {
  @track apiKey = "";
  @track selectedRegion = "sandbox";
  @track dedicatedUrl = "";
  @track isLoading = false;
  @track isSearchingContacts = false;
  @track hasExistingKey = false;
  @track currentApiKeyMask = "";
  @track internalSignerSearchTerm = "";
  @track internalSignerOptions = [];
  @track selectedInternalSignerId;
  @track selectedInternalSignerLabel = "";
  @track selectedInternalSignerRole = "signer";
  @track internalSignerSearchMessage = "";

  get regionOptions() {
    return [
      { label: "Sandbox (sandbox.zefort.com)", value: "sandbox" },
      { label: "EU Production (my.zefort.com)", value: "eu" },
      { label: "US Production (us.zefort.com)", value: "us" },
      { label: "Custom Domain", value: "dedicated" },
    ];
  }

  get showDedicatedUrlField() {
    return this.selectedRegion === "dedicated";
  }

  get disableInternalSignerSearch() {
    return (
      this.isLoading ||
      this.isSearchingContacts ||
      !this.internalSignerSearchTerm ||
      this.internalSignerSearchTerm.trim().length < 2
    );
  }

  get hasInternalSignerOptions() {
    return this.internalSignerOptions.length > 0;
  }

  get hasSelectedInternalSigner() {
    return !!this.selectedInternalSignerId;
  }

  get internalSignerRoleOptions() {
    return [
      { label: "Signer", value: "signer" },
      { label: "Approver", value: "approver" },
      { label: "CC", value: "cc" },
    ];
  }

  async connectedCallback() {
    await this.loadExistingSettings();
  }

  async loadExistingSettings() {
    try {
      // Load region
      const region = await getRegion();
      if (region) {
        this.selectedRegion = region;
      }

      // Load API key mask only; never fetch full secret to client
      try {
        const keyMask = await getApiKeyMask();
        if (keyMask) {
          this.hasExistingKey = true;
          this.currentApiKeyMask = keyMask;
        }
      } catch {
        // API key might not exist yet, which is fine.
      }

      try {
        const internalSigner = await getInternalSigner();
        if (internalSigner) {
          this.applyInternalSigner(internalSigner);
        }
      } catch {
        // Internal signer might not be configured yet, which is fine.
      }
    } catch {
      this.showToast("Error", "Error loading settings", "error");
    }
  }

  handleRegionChange(event) {
    this.selectedRegion = event.detail.value;
  }

  handleDedicatedUrlChange(event) {
    this.dedicatedUrl = event.detail.value;
  }

  handleApiKeyChange(event) {
    this.apiKey = event.detail.value;
  }

  handleInternalSignerSearchTermChange(event) {
    this.internalSignerSearchTerm = event.detail.value;
  }

  handleInternalSignerChange(event) {
    this.selectedInternalSignerId = event.detail.value;
    const selectedOption = this.internalSignerOptions.find(
      (option) => option.value === this.selectedInternalSignerId,
    );
    this.selectedInternalSignerLabel = selectedOption?.label || "";
    this.internalSignerSearchMessage = "";
  }

  handleInternalSignerRoleChange(event) {
    this.selectedInternalSignerRole = event.detail.value || "signer";
  }

  async handleSearchInternalSignerContacts() {
    if (this.disableInternalSignerSearch) {
      return;
    }

    this.internalSignerSearchMessage = "";
    this.isSearchingContacts = true;
    try {
      const results = await searchContacts({
        searchTerm: this.internalSignerSearchTerm,
      });
      this.internalSignerOptions = this.mergeInternalSignerOptions(
        (results || []).map((contact) => this.toInternalSignerOption(contact)),
      );
      if (this.internalSignerOptions.length === 0) {
        this.internalSignerSearchMessage =
          "No matching contacts with e-mail found.";
      }
    } catch (error) {
      this.showToast(
        "Error",
        error.body?.message || "Error searching contacts",
        "error",
      );
    } finally {
      this.isSearchingContacts = false;
    }
  }

  handleClearInternalSigner() {
    this.selectedInternalSignerId = undefined;
    this.selectedInternalSignerLabel = "";
    this.selectedInternalSignerRole = "signer";
    this.internalSignerSearchTerm = "";
    this.internalSignerOptions = [];
    this.internalSignerSearchMessage = "";
  }

  async handleSave() {
    if (this.selectedRegion === "dedicated" && !this.dedicatedUrl) {
      this.showToast("Error", "Please enter your custom domain", "error");
      return;
    }

    this.isLoading = true;
    try {
      // Save region settings
      await setRegion({
        region: this.selectedRegion,
        dedicatedUrl: this.dedicatedUrl,
      });

      await setInternalSigner({
        contactId: this.selectedInternalSignerId || null,
        role: this.selectedInternalSignerId ? this.selectedInternalSignerRole : null,
      });

      // Only save API key if one was entered
      if (this.apiKey) {
        await saveUserApiKey({ apiKey: this.apiKey });
        this.hasExistingKey = true;
        this.currentApiKeyMask = `...${this.apiKey.slice(-4)}`;
        this.apiKey = ""; // Clear the input
      }

      this.showToast("Success", "Settings saved successfully", "success");

      // Dispatch a custom event to notify parent components that settings have been updated
      this.dispatchEvent(new CustomEvent("settingssaved"));
    } catch (error) {
      this.showToast(
        "Error",
        error.body?.message || "Error saving settings",
        "error",
      );
    } finally {
      this.isLoading = false;
    }
  }

  applyInternalSigner(contact) {
    const selectedOption = this.toInternalSignerOption(contact);
    this.selectedInternalSignerId = selectedOption.value;
    this.selectedInternalSignerLabel = selectedOption.label;
    this.selectedInternalSignerRole = contact.role || "signer";
    this.internalSignerOptions = [selectedOption];
  }

  toInternalSignerOption(contact) {
    return {
      label:
        contact.label ||
        `${contact.name || "(No name)"} (${contact.email || "No e-mail"})`,
      value: contact.id,
    };
  }

  mergeInternalSignerOptions(options) {
    const merged = [];
    const seen = new Set();

    if (this.selectedInternalSignerId && this.selectedInternalSignerLabel) {
      merged.push({
        value: this.selectedInternalSignerId,
        label: this.selectedInternalSignerLabel,
      });
      seen.add(this.selectedInternalSignerId);
    }

    (options || []).forEach((option) => {
      if (!option?.value || seen.has(option.value)) {
        return;
      }
      merged.push(option);
      seen.add(option.value);
    });

    return merged;
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