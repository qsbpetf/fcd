import { LightningElement, api, track, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getLaunchContext from "@salesforce/apex/ZefortSignService.getLaunchContext";
import listAccountContacts from "@salesforce/apex/ZefortSignService.listAccountContacts";
import searchAccounts from "@salesforce/apex/ZefortSignService.searchAccounts";
import startSignRequest from "@salesforce/apex/ZefortSignService.startSignRequestFromClient";

export default class ZefortSignFlow extends LightningElement {
  _recordId;
  _pageRecordId;
  _isConnected = false;
  _lastLoadedRecordId;

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    if (
      this._isConnected &&
      this.resolvedRecordId &&
      this.resolvedRecordId !== this._lastLoadedRecordId
    ) {
      this.loadContext();
    }
  }
  @track isLoading = true;
  @track isSubmitting = false;
  @track isSearchingAccounts = false;
  @track error;
  @track resolutionMessage;
  @track submitError;
  @track submitSuccessMessage;
  @track context;
  @track selectedMainFileId;
  @track selectedAttachmentIds = [];
  @track participants = [];
  @track selectedContactToAddId;
  @track selectedRoleToAdd = "signer";
  @track manualAccountSearchTerm = "";
  @track manualAccountOptions = [];
  @track selectedManualAccountId;

  roleOptions = [
    { label: "Signer", value: "signer" },
    { label: "Approver", value: "approver" },
    { label: "CC", value: "cc" },
  ];

  get resolvedRecordId() {
    return this.recordId || this._pageRecordId || null;
  }

  @wire(CurrentPageReference)
  handleCurrentPageReference(pageRef) {
    this._pageRecordId =
      pageRef?.attributes?.recordId ||
      pageRef?.state?.recordId ||
      pageRef?.state?.c__recordId ||
      null;
    if (
      this._isConnected &&
      this.resolvedRecordId &&
      this.resolvedRecordId !== this._lastLoadedRecordId
    ) {
      this.loadContext();
    }
  }

  connectedCallback() {
    this._isConnected = true;
    if (this.resolvedRecordId) {
      this.loadContext();
    }
  }

  async loadContext() {
    if (!this.resolvedRecordId) {
      return;
    }

    const currentRecordId = this.resolvedRecordId;
    this._lastLoadedRecordId = currentRecordId;

    this.isLoading = true;
    this.error = undefined;
    this.resolutionMessage = undefined;
    this.submitError = undefined;
    this.submitSuccessMessage = undefined;
    this.selectedMainFileId = undefined;
    this.selectedAttachmentIds = [];
    this.selectedContactToAddId = undefined;
    this.selectedRoleToAdd = "signer";
    this.participants = [];
    this.manualAccountSearchTerm = "";
    this.manualAccountOptions = [];
    this.selectedManualAccountId = undefined;

    try {
      const loadedContext = await getLaunchContext({
        recordId: currentRecordId,
        objectApiName: null,
      });
      this.context = loadedContext || {
        success: false,
        files: [],
        contacts: [],
        prefills: [],
      };
      if (!this.context.success) {
        this.resolutionMessage =
          this.context.message ||
          "Could not resolve account for this source record.";
        this.context = {
          ...this.context,
          accountId: null,
          contacts: this.context.contacts || [],
          prefills: this.context.prefills || [],
          files: this.context.files || [],
        };
      } else {
        this.initializeParticipants();
      }
    } catch (loadError) {
      this.error =
        loadError.body?.message ||
        loadError.message ||
        "Failed to load launch context.";
    } finally {
      this.isLoading = false;
    }
  }

  get requiresManualAccountSelection() {
    return !!this.resolutionMessage;
  }

  get hasResolvedAccount() {
    return !!this.context?.success || !!this.context?.accountId;
  }

  get disableAccountSearch() {
    return (
      this.isLoading ||
      this.isSearchingAccounts ||
      this.isSubmitting ||
      !this.manualAccountSearchTerm ||
      this.manualAccountSearchTerm.trim().length < 2
    );
  }

  get hasManualAccountOptions() {
    return this.manualAccountOptions.length > 0;
  }

  get fileOptions() {
    return (this.context?.files || []).map((file) => ({
      label: `${file.title} (${this.formatBytes(file.fileSize)})`,
      value: file.contentVersionId,
    }));
  }

  get hasFiles() {
    return (this.context?.files || []).length > 0;
  }

  get contactCount() {
    return (this.context?.contacts || []).length;
  }

  get hasParticipants() {
    return this.participants.length > 0;
  }

  get hasInternalSignerPrefill() {
    return !!this.context?.internalSignerPrefill?.contactId;
  }

  get showInternalSignerMessage() {
    return !this.hasInternalSignerPrefill;
  }

  get availableContactOptions() {
    const selectedIds = new Set();
    this.participants.forEach((participant) => {
      if (participant?.contactId) {
        selectedIds.add(participant.contactId);
      }
    });
    return (this.context?.contacts || [])
      .filter((contact) => !selectedIds.has(contact.id))
      .map((contact) => ({
        label: `${contact.name || "(No name)"} (${contact.email || "No e-mail"})`,
        value: contact.id,
      }));
  }

  get disableAddParticipant() {
    return (
      !this.selectedContactToAddId ||
      this.availableContactOptions.length === 0 ||
      this.isLoading ||
      this.isSubmitting
    );
  }

  get hasSigningRoleParticipant() {
    return this.participants.some(
      (participant) =>
        participant.role === "signer" || participant.role === "approver",
    );
  }

  get submitDisabled() {
    return (
      this.isLoading ||
      this.isSubmitting ||
      !!this.error ||
      !this.resolvedRecordId ||
      !this.hasResolvedAccount ||
      !this.selectedMainFileId ||
      !this.hasParticipants ||
      !this.hasSigningRoleParticipant
    );
  }

  handleMainFileChange(event) {
    this.selectedMainFileId = event.detail.value;
    this.selectedAttachmentIds = this.selectedAttachmentIds.filter(
      (id) => id !== this.selectedMainFileId,
    );
  }

  handleAttachmentChange(event) {
    const selected = event.detail.value || [];
    this.selectedAttachmentIds = selected.filter(
      (id) => id !== this.selectedMainFileId,
    );
  }

  handleContactToAddChange(event) {
    this.selectedContactToAddId = event.detail.value;
  }

  handleRoleToAddChange(event) {
    this.selectedRoleToAdd = this.normalizeRole(event.detail.value);
  }

  handleManualAccountSearchTermChange(event) {
    this.manualAccountSearchTerm = event.detail.value;
  }

  async handleSearchAccounts() {
    this.submitError = undefined;
    this.manualAccountOptions = [];
    this.selectedManualAccountId = undefined;
    if (this.disableAccountSearch) {
      return;
    }

    this.isSearchingAccounts = true;
    try {
      const rows = await searchAccounts({
        searchTerm: this.manualAccountSearchTerm,
      });
      this.manualAccountOptions = (rows || []).map((row) => ({
        label: row.label,
        value: row.id,
      }));
      if (this.manualAccountOptions.length === 0) {
        this.submitError =
          "No matching accounts found. Try a different account name.";
      }
    } catch (searchError) {
      this.submitError =
        searchError.body?.message ||
        searchError.message ||
        "Failed to search accounts.";
    } finally {
      this.isSearchingAccounts = false;
    }
  }

  async handleManualAccountChange(event) {
    const accountId = event.detail.value;
    this.selectedManualAccountId = accountId;
    this.submitError = undefined;
    if (!accountId) {
      this.context = {
        ...this.context,
        accountId: null,
        contacts: [],
      };
      this.participants = [];
      return;
    }

    this.isLoading = true;
    try {
      const contacts = await listAccountContacts({ accountId });
      this.context = {
        ...this.context,
        accountId,
        contacts: contacts || [],
      };
      this.initializeParticipants();
    } catch (loadError) {
      this.submitError =
        loadError.body?.message ||
        loadError.message ||
        "Failed to load contacts for selected account.";
    } finally {
      this.isLoading = false;
    }
  }

  handleAddParticipant() {
    if (!this.selectedContactToAddId) {
      return;
    }

    const contact = (this.context?.contacts || []).find(
      (row) => row.id === this.selectedContactToAddId,
    );
    if (!contact) {
      return;
    }

    this.participants = [
      ...this.participants,
      {
        participantKey: this.buildContactParticipantKey(contact.id),
        contactId: contact.id,
        name: contact.name || "(No name)",
        email: contact.email || "",
        role: this.normalizeRole(this.selectedRoleToAdd),
        source: "account_contact",
        sourceLabel: this.getSourceLabel("account_contact"),
      },
    ];
    this.selectedContactToAddId = undefined;
    this.selectedRoleToAdd = "signer";
  }

  handleParticipantRoleChange(event) {
    const participantKey = event.target.dataset.participantKey;
    const role = this.normalizeRole(event.detail.value);
    this.participants = this.participants.map((participant) => {
      if (participant.participantKey === participantKey) {
        return { ...participant, role };
      }
      return participant;
    });
  }

  handleRemoveParticipant(event) {
    const participantKey = event.target.dataset.participantKey;
    this.participants = this.participants.filter(
      (participant) => participant.participantKey !== participantKey,
    );
  }

  async handleSubmit() {
    this.submitError = undefined;
    this.submitSuccessMessage = undefined;

    if (this.submitDisabled) {
      if (!this.hasResolvedAccount) {
        this.submitError = "Select an account before launching this request.";
      } else {
        this.submitError =
          "Select a main file and at least one signer or approver before launching.";
      }
      return;
    }

    this.isSubmitting = true;
    try {
      const participantsPayload = this.participants.map((participant) => {
        if (participant.contactId) {
          return {
            contactId: participant.contactId,
            role: this.normalizeRole(participant.role),
          };
        }
        return {
          name: participant.name || null,
          email: participant.email || null,
          role: this.normalizeRole(participant.role),
        };
      });

      const response = await startSignRequest({
        recordId: this.resolvedRecordId,
        objectApiName: this.context?.objectApiName || null,
        mainFileId: this.selectedMainFileId,
        attachmentFileIds: this.selectedAttachmentIds,
        participantsJson: JSON.stringify(participantsPayload),
        manualAccountId: this.context?.success
          ? null
          : this.context?.accountId || null,
      });

      this.submitSuccessMessage =
        response?.message ||
        `Sign request launched. eSign ID: ${response?.zefortEsignId || ""}`;
    } catch (submitFailure) {
      this.submitError =
        submitFailure.body?.message ||
        submitFailure.message ||
        "Failed to launch sign request.";
    } finally {
      this.isSubmitting = false;
    }
  }

  initializeParticipants() {
    const contactsById = new Map(
      (this.context?.contacts || []).map((contact) => [contact.id, contact]),
    );
    const deduped = new Map();

    const addContactParticipant = (participant, fallbackSource) => {
      const contactId = participant?.contactId;
      if (!contactId || deduped.has(contactId)) {
        return false;
      }

      const contact = contactsById.get(contactId);
      const name = contact?.name || participant?.name || "(No name)";
      const email = contact?.email || participant?.email || "";
      deduped.set(contactId, {
        participantKey: this.buildContactParticipantKey(contactId),
        contactId,
        name,
        email,
        role: this.normalizeRole(participant?.role),
        source: participant?.source || fallbackSource,
        sourceLabel: this.getSourceLabel(participant?.source || fallbackSource),
      });
      return true;
    };

    addContactParticipant(
      this.context?.internalSignerPrefill,
      "internal_signer",
    );

    (this.context?.prefills || []).forEach((participant) => {
      addContactParticipant(participant, "context_rule");
    });

    this.participants = Array.from(deduped.values());
  }

  buildContactParticipantKey(contactId) {
    return `contact:${contactId}`;
  }

  getSourceLabel(source) {
    if (source === "internal_signer") {
      return "Company signer";
    }
    if (source === "context_rule") {
      return "Context rule";
    }
    if (source === "account_contact") {
      return "Account contact";
    }
    return "Manual participant";
  }

  normalizeRole(role) {
    const normalized = (role || "").toLowerCase();
    if (
      normalized === "signer" ||
      normalized === "approver" ||
      normalized === "cc"
    ) {
      return normalized;
    }
    return "signer";
  }

  formatBytes(bytes) {
    if (!bytes || bytes <= 0) {
      return "0 B";
    }
    const units = ["B", "KB", "MB", "GB"];
    let value = bytes;
    let unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    return `${value.toFixed(unitIndex === 0 ? 0 : 1)} ${units[unitIndex]}`;
  }
}