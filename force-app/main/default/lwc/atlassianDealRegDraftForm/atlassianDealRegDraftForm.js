import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getPartnerAccounts from '@salesforce/apex/AtlassianDealRegApiPartnerAccounts.getPartnerAccountsStatic';
import getRegistration from '@salesforce/apex/AtlassianDealRegApiRegistrations.getRegistrationStatic';
import createDealDraft from '@salesforce/apex/AtlassianDealRegDraftController.createDealDraft';
import updateDealDraft from '@salesforce/apex/AtlassianDealRegDraftController.updateDealDraft';
import updateDealDraftByRegistrationId from '@salesforce/apex/AtlassianDealRegDraftController.updateDealDraftByRegistrationId';
import findSubmissionByRegistrationId from '@salesforce/apex/AtlassianDealRegDraftController.findSubmissionByRegistrationId';
import submitDealDraft from '@salesforce/apex/AtlassianDealRegDraftController.submitDealDraft';
import pollJobStatus from '@salesforce/apex/AtlassianDealRegDraftController.pollJobStatus';
import getSubmissionRecord from '@salesforce/apex/AtlassianDealRegDraftController.getSubmissionRecord';

const PLATFORM_OPTIONS = [
    { label: 'Cloud', value: 'CLOUD' },
    { label: 'Data Center', value: 'DATA_CENTER' },
    { label: 'Both', value: 'BOTH' }
];

const BUDGET_OPTIONS = [
    { label: '-- Select --', value: '' },
    { label: 'Yes', value: 'YES' },
    { label: 'No', value: 'NO' },
    { label: 'Unknown', value: 'UNKNOWN' }
];

const SALES_TYPE_OPTIONS = [
    { label: '-- Select --', value: '' },
    { label: 'New', value: 'NEW' },
    { label: 'Upgrade', value: 'UPGRADE' },
    { label: 'Renewal', value: 'RENEWAL' },
    { label: 'New Product', value: 'NEW_PRODUCT' },
    { label: 'Expansion Upgrade', value: 'EXPANSION_UPGRADE' },
    { label: 'Platform Change With Expansion Upgrade', value: 'PLATFORM_CHANGE_WITH_EXPANSION_UPGRADE' },
    { label: 'Platform Change Without Expansion Upgrade', value: 'PLATFORM_CHANGE_WITHOUT_EXPANSION_UPGRADE' }
];

const RFP_OPTIONS = [
    { label: '-- Select --', value: '' },
    { label: 'Atlassian Specified Product Proposal', value: 'ATLASSIAN_SPECIFIED_PRODUCT_PROPOSAL' },
    { label: 'General Solution Proposal', value: 'GENERAL_SOLUTION_PROPOSAL' },
    { label: 'Government Tender', value: 'GOVERNMENT_TENDER' }
];

const PRODUCT_OPTIONS = [
    { label: 'Atlas', value: 'ATLAS' },
    { label: 'Atlassian Access', value: 'ATLASSIAN_ACCESS' },
    { label: 'Atlassian Guard', value: 'ATLASSIAN_GUARD' },
    { label: 'Bamboo', value: 'BAMBOO' },
    { label: 'Beacon', value: 'BEACON' },
    { label: 'Bitbucket', value: 'BITBUCKET' },
    { label: 'Compass', value: 'COMPASS' },
    { label: 'Confluence', value: 'CONFLUENCE' },
    { label: 'Crowd', value: 'CROWD' },
    { label: 'Crucible', value: 'CRUCIBLE' },
    { label: 'Fisheye', value: 'FISHEYE' },
    { label: 'Jira', value: 'JIRA' },
    { label: 'Jira Align', value: 'JIRA_ALIGN' },
    { label: 'Jira Product Discovery', value: 'JIRA_PRODUCT_DISCOVERY' },
    { label: 'Jira Service Management', value: 'JIRA_SERVICE_MANAGEMENT' },
    { label: 'Jira Service Management 200 or Less Users', value: 'JIRA_SERVICE_MANAGEMENT_200_OR_LESS_USERS' },
    { label: 'Jira Service Management 201 or More Users', value: 'JIRA_SERVICE_MANAGEMENT_201_OR_MORE_USERS' },
    { label: 'Jira Service Management 500 or Less Users', value: 'JIRA_SERVICE_MANAGEMENT_500_OR_LESS_USERS' },
    { label: 'Jira Service Management 501 or More Users', value: 'JIRA_SERVICE_MANAGEMENT_501_OR_MORE_USERS' },
    { label: 'Jira Software', value: 'JIRA_SOFTWARE' },
    { label: 'Jira Software Management', value: 'JIRA_SOFTWARE_MANAGEMENT' },
    { label: 'Jira Work Management', value: 'JIRA_WORK_MANAGEMENT' },
    { label: 'Jira Work Management Expansion Only', value: 'JIRA_WORK_MANAGEMENT_EXPANSION_ONLY' },
    { label: 'Loom', value: 'LOOM' },
    { label: 'Loom New Only', value: 'LOOM_NEW_ONLY' },
    { label: 'Opsgenie', value: 'OPSGENIE' },
    { label: 'Rovo', value: 'ROVO' },
    { label: 'Sourcetree', value: 'SOURCETREE' },
    { label: 'Statuspage', value: 'STATUSPAGE' },
    { label: 'Strategy Collection', value: 'STRATEGY_COLLECTION' },
    { label: 'Teamwork Collection', value: 'TEAMWORK_COLLECTION' },
    { label: 'Trello', value: 'TRELLO' },
    { label: 'Customer Managed Keys CMK', value: 'CUSTOMER_MANAGED_KEYS_CMK' },
    { label: 'Rovo Dev', value: 'ROVO_DEV' },
    { label: 'Service Collection', value: 'SERVICE_COLLECTION' },
    { label: 'Service Collection 200 or Less Users', value: 'SERVICE_COLLECTION_200_OR_LESS_USERS' },
    { label: 'Service Collection 201 or More Users', value: 'SERVICE_COLLECTION_201_OR_MORE_USERS' }
];

const IMMUTABLE_STATUSES = new Set(['APPROVED', 'EXPIRED', 'CLOSED_WON', 'CLOSED_LOST', 'CLOSED', 'REJECTED']);

export default class AtlassianDealRegDraftForm extends NavigationMixin(LightningElement) {
    @api recordId;
    @api title;
    @api registrationId;
    @api partnerAccountId;

    partnerOptions = [];
    selectedPartnerId = '';
    parentRegistrationId = '';
    dealName = '';
    customerDomain = '';
    customerContactEmailId = '';
    partnerSalesRepresentativeEmailId = '';
    partnerSubmittedOpportunityNumber = '';
    products = [];
    customerHasCloudSite = '';
    cloudSite = '';
    notes = '';
    termsAccepted = false;
    sowConfirmed = false;
    termsConfirmed = false;
    detailedDescription = '';
    platform = '';
    estimatedRevenue = '';
    estimatedOpportunityCloseDate = '';
    comments = '';
    dealRegDcExceptionReason = '';
    budgetAllocated = '';
    customerKeyDecisionMakersEngagedInProcess = false;
    crucialEvent = '';
    rfpRelated = false;
    rfpRelatedTo = '';
    salesType = '';
    senOrEntitlementNumber = '';
    additionalInfo = '';
    eccListedAboveIsKeyDecisionMaker = false;
    eccKeyDecisionMaker = {
        endCustomerFirstName: '',
        endCustomerLastName: '',
        endCustomerEmail: '',
        endCustomerJobTitle: ''
    };

    platformOptions = PLATFORM_OPTIONS;
    budgetOptions = BUDGET_OPTIONS;
    salesTypeOptions = SALES_TYPE_OPTIONS;
    rfpOptions = RFP_OPTIONS;
    productOptions = PRODUCT_OPTIONS;

    isLoading = false;
    isSaving = false;
    isSubmitting = false;
    isPolling = false;
    hasError = false;
    errorMessage = '';

    get isCreateMode() {
        return !this.recordId && !this.registrationId;
    }

    get isEditMode() {
        return !!this.recordId || !!this.registrationId;
    }

    get isEditByApiMode() {
        return !!this.registrationId && !!this.partnerAccountId && !this.recordId;
    }

    get isFormReadOnly() {
        return IMMUTABLE_STATUSES.has((this.submissionStatus || '').toUpperCase());
    }

    get canSubmit() {
        return this.isEditMode && this.submissionStatus === 'DRAFT' && !this.isFormReadOnly;
    }

    get canPoll() {
        return this.isEditMode && this.submissionStatus === 'IN_PROGRESS';
    }

    get _effectiveRecordId() {
        return this.recordId || this._resolvedRecordId;
    }

    get pageTitle() {
        if (this.title) return this.title;
        return this.isCreateMode ? 'Create Deal Draft' : 'Edit Deal Draft';
    }

    get saveButtonLabel() {
        return this.isCreateMode ? 'Create' : 'Save';
    }

    submissionStatus = '';
    submissionJobId = '';

    connectedCallback() {
        if (this.isCreateMode) {
            this.loadPartnerAccounts();
        } else if (this.isEditByApiMode) {
            this.loadRegistrationByApi();
        } else {
            this.loadSubmissionAndRegistration();
        }
    }

    loadPartnerAccounts() {
        this.isLoading = true;
        this.hasError = false;
        getPartnerAccounts({ forceRefresh: false })
            .then((result) => {
                if (result && result.partnerAccounts && result.partnerAccounts.length > 0) {
                    this.partnerOptions = [
                        { label: '-- Select Partner Account --', value: '' },
                        ...result.partnerAccounts.map((acc) => ({
                            label: acc.accountName || acc.partnerId,
                            value: acc.partnerId
                        }))
                    ];
                }
                this.isLoading = false;
            })
            .catch((err) => {
                this.hasError = true;
                this.errorMessage = this._extractError(err);
                this.isLoading = false;
            });
    }

    async loadSubmissionAndRegistration() {
        this.isLoading = true;
        this.hasError = false;
        try {
            const sub = await getSubmissionRecord({ recordId: this.recordId });
            this.selectedPartnerId = sub.Partner_Account_Id__c || '';
            this.submissionStatus = sub.Status__c || '';
            this.submissionJobId = sub.Job_Id__c || '';

            if (sub.Registration_Id__c && sub.Partner_Account_Id__c) {
                const reg = await getRegistration({
                    partnerAccountId: sub.Partner_Account_Id__c,
                    registrationId: sub.Registration_Id__c,
                    programType: 'DEAL_REGISTRATION'
                });
                this._populateFromRegistration(reg);
            }
        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    _resolvedRecordId = null;

    async loadRegistrationByApi() {
        this.isLoading = true;
        this.hasError = false;
        try {
            this.selectedPartnerId = this.partnerAccountId || '';
            const found = await findSubmissionByRegistrationId({
                partnerAccountId: this.partnerAccountId,
                registrationId: this.registrationId
            });
            if (found && found.recordId) {
                this._resolvedRecordId = found.recordId;
                this.submissionStatus = found.status || '';
                this.submissionJobId = found.jobId || '';
            } else {
                this._resolvedRecordId = null;
            }
            const reg = await getRegistration({
                partnerAccountId: this.partnerAccountId,
                registrationId: this.registrationId,
                programType: 'DEAL_REGISTRATION'
            });
            this.submissionStatus = this.submissionStatus || reg.status || '';
            this._populateFromRegistration(reg);
        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

    _populateFromRegistration(reg) {
        this.parentRegistrationId = reg.parentRegistrationId || '';
        this.dealName = reg.dealName || '';
        this.customerDomain = reg.customerDomain || '';
        this.customerContactEmailId = reg.customerContactEmailId || '';
        this.partnerSalesRepresentativeEmailId = reg.partnerSalesRepresentativeEmailId || '';
        this.partnerSubmittedOpportunityNumber = reg.partnerSubmittedOpportunityNumber || '';
        this.products = Array.isArray(reg.products) ? [...reg.products] : [];
        this.customerHasCloudSite = reg.customerHasCloudSite || '';
        this.cloudSite = reg.cloudSite || '';
        this.notes = reg.notes || '';
        this.termsAccepted = reg.termsAccepted === true;
        this.sowConfirmed = reg.sowConfirmed === true;
        this.termsConfirmed = reg.termsConfirmed === true;
        this.detailedDescription = reg.detailedDescription || '';
        this.platform = reg.platform || '';
        this.estimatedRevenue = reg.estimatedRevenue != null ? String(reg.estimatedRevenue) : '';
        this.estimatedOpportunityCloseDate = reg.estimatedOpportunityCloseDate || '';
        this.comments = reg.comments || '';
        this.dealRegDcExceptionReason = reg.dealRegDcExceptionReason || '';
        this.budgetAllocated = reg.budgetAllocated || '';
        this.customerKeyDecisionMakersEngagedInProcess = reg.customerKeyDecisionMakersEngagedInProcess === true;
        this.crucialEvent = reg.crucialEvent || '';
        this.rfpRelated = reg.rfpRelated === true;
        this.rfpRelatedTo = reg.rfpRelatedTo || '';
        this.salesType = reg.salesType || '';
        this.senOrEntitlementNumber = reg.senOrEntitlementNumber || '';
        this.additionalInfo = reg.additionalInfo || '';
        this.eccListedAboveIsKeyDecisionMaker = reg.eccListedAboveIsKeyDecisionMaker === true;
        if (reg.eccKeyDecisionMaker && typeof reg.eccKeyDecisionMaker === 'object') {
            this.eccKeyDecisionMaker = {
                endCustomerFirstName: reg.eccKeyDecisionMaker.endCustomerFirstName || '',
                endCustomerLastName: reg.eccKeyDecisionMaker.endCustomerLastName || '',
                endCustomerEmail: reg.eccKeyDecisionMaker.endCustomerEmail || '',
                endCustomerJobTitle: reg.eccKeyDecisionMaker.endCustomerJobTitle || ''
            };
        }
    }

    handlePartnerChange(event) {
        this.selectedPartnerId = event.detail.value;
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        if (field) this[field] = event.detail.value !== undefined ? event.detail.value : '';
    }

    handleCheckboxChange(event) {
        const field = event.target.dataset.field;
        if (field) this[field] = event.detail.checked === true;
    }

    get productsValue() {
        return this.products && this.products.length > 0 ? this.products : [];
    }

    handleProductsChange(event) {
        const val = event.detail.value;
        this.products = typeof val === 'string' ? (val ? val.split(',') : []) : (Array.isArray(val) ? val : []);
    }

    handleEccChange(event) {
        const field = event.target.dataset.field;
        if (field) {
            this.eccKeyDecisionMaker = { ...this.eccKeyDecisionMaker, [field]: event.detail.value || '' };
        }
    }

    _buildPayload() {
        const payload = {};
        if (this.parentRegistrationId) payload.parentRegistrationId = this.parentRegistrationId;
        if (this.dealName) payload.dealName = this.dealName;
        payload.programType = 'DEAL_REGISTRATION';
        if (this.partnerSubmittedOpportunityNumber) payload.partnerSubmittedOpportunityNumber = this.partnerSubmittedOpportunityNumber;
        if (this.products && this.products.length > 0) payload.products = [...this.products];
        if (this.customerHasCloudSite) payload.customerHasCloudSite = this.customerHasCloudSite;
        if (this.cloudSite) payload.cloudSite = this.cloudSite;
        if (this.notes) payload.notes = this.notes;
        payload.termsAccepted = this.termsAccepted;
        payload.sowConfirmed = this.sowConfirmed;
        payload.termsConfirmed = this.termsConfirmed;
        if (this.detailedDescription) payload.detailedDescription = this.detailedDescription;
        if (this.platform) payload.platform = this.platform;
        if (this.estimatedRevenue) payload.estimatedRevenue = parseFloat(this.estimatedRevenue) || undefined;
        if (this.customerContactEmailId) payload.customerContactEmailId = this.customerContactEmailId;
        if (this.customerDomain) payload.customerDomain = this.customerDomain;
        if (this.partnerSalesRepresentativeEmailId) payload.partnerSalesRepresentativeEmailId = this.partnerSalesRepresentativeEmailId;
        if (this.estimatedOpportunityCloseDate) payload.estimatedOpportunityCloseDate = this.estimatedOpportunityCloseDate;
        if (this.comments) payload.comments = this.comments;
        if (this.dealRegDcExceptionReason) payload.dealRegDcExceptionReason = this.dealRegDcExceptionReason;
        if (this.budgetAllocated) payload.budgetAllocated = this.budgetAllocated;
        payload.customerKeyDecisionMakersEngagedInProcess = this.customerKeyDecisionMakersEngagedInProcess;
        if (this.crucialEvent) payload.crucialEvent = this.crucialEvent;
        payload.rfpRelated = this.rfpRelated;
        if (this.rfpRelatedTo) payload.rfpRelatedTo = this.rfpRelatedTo;
        if (this.salesType) payload.salesType = this.salesType;
        if (this.senOrEntitlementNumber) payload.senOrEntitlementNumber = this.senOrEntitlementNumber;
        if (this.additionalInfo) payload.additionalInfo = this.additionalInfo;
        payload.eccListedAboveIsKeyDecisionMaker = this.eccListedAboveIsKeyDecisionMaker;
        const ecc = this.eccKeyDecisionMaker;
        if (ecc && (ecc.endCustomerFirstName || ecc.endCustomerLastName || ecc.endCustomerEmail || ecc.endCustomerJobTitle)) {
            payload.eccKeyDecisionMaker = {};
            if (ecc.endCustomerFirstName) payload.eccKeyDecisionMaker.endCustomerFirstName = ecc.endCustomerFirstName;
            if (ecc.endCustomerLastName) payload.eccKeyDecisionMaker.endCustomerLastName = ecc.endCustomerLastName;
            if (ecc.endCustomerEmail) payload.eccKeyDecisionMaker.endCustomerEmail = ecc.endCustomerEmail;
            if (ecc.endCustomerJobTitle) payload.eccKeyDecisionMaker.endCustomerJobTitle = ecc.endCustomerJobTitle;
        }
        const payloadString = JSON.stringify(payload);
        console.log('payloadString', payloadString);
        return payloadString;
    }

    handleSave() {
        if (this.isFormReadOnly) return;
        if (!this.dealName) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Validation', message: 'Deal Name is required', variant: 'error' }));
            return;
        }

        if (this.isCreateMode) {
            if (!this.selectedPartnerId) {
                this.dispatchEvent(new ShowToastEvent({ title: 'Validation', message: 'Partner Account is required', variant: 'error' }));
                return;
            }
            this._handleCreate();
        } else {
            this._handleUpdate();
        }
    }

    _handleCreate() {
        this.isSaving = true;
        this.hasError = false;
        createDealDraft({ partnerAccountId: this.selectedPartnerId, body: this._buildPayload() })
            .then((result) => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Deal draft created', variant: 'success' }));
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: result.recordId, objectApiName: 'AtlassianDealRegSubmission__c', actionName: 'view' }
                });
            })
            .catch((err) => {
                this.hasError = true;
                this.errorMessage = this._extractError(err);
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.errorMessage, variant: 'error' }));
            })
            .finally(() => { this.isSaving = false; });
    }

    _handleUpdate() {
        this.isSaving = true;
        this.hasError = false;
        const recordId = this._effectiveRecordId;
        const promise = recordId
            ? updateDealDraft({ recordId, body: this._buildPayload() })
            : updateDealDraftByRegistrationId({
                partnerAccountId: this.partnerAccountId,
                registrationId: this.registrationId,
                body: this._buildPayload()
            });
        promise
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Draft updated', variant: 'success' }));
                this.dispatchEvent(new CustomEvent('updated', { bubbles: true, composed: true }));
            })
            .catch((err) => {
                this.hasError = true;
                this.errorMessage = this._extractError(err);
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.errorMessage, variant: 'error' }));
            })
            .finally(() => { this.isSaving = false; });
    }

    handleSubmit() {
        if (!this._effectiveRecordId) return;
        this.isSubmitting = true;
        this.hasError = false;
        submitDealDraft({ recordId: this._effectiveRecordId })
            .then((result) => {
                this.submissionStatus = result.status;
                this.submissionJobId = result.jobId;
                this.dispatchEvent(new ShowToastEvent({ title: 'Submitted', message: 'Draft submitted. Job ID: ' + result.jobId, variant: 'success' }));
            })
            .catch((err) => {
                this.hasError = true;
                this.errorMessage = this._extractError(err);
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.errorMessage, variant: 'error' }));
            })
            .finally(() => { this.isSubmitting = false; });
    }

    handlePollStatus() {
        if (!this._effectiveRecordId) return;
        this.isPolling = true;
        this.hasError = false;
        pollJobStatus({ recordId: this._effectiveRecordId })
            .then((result) => {
                this.submissionStatus = result.status;
                this.dispatchEvent(new ShowToastEvent({ title: 'Status', message: 'Status: ' + result.status, variant: 'success' }));
            })
            .catch((err) => {
                this.hasError = true;
                this.errorMessage = this._extractError(err);
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: this.errorMessage, variant: 'error' }));
            })
            .finally(() => { this.isPolling = false; });
    }

    _extractError(err) {
        if (!err) return 'An unknown error occurred';
        if (typeof err === 'string') return err;
        const body = err.body || {};
        const msg = body.message || err.message;
        const statusCode = body.statusCode ?? body.status;
        const errors = body.errors;
        const parts = [];
        if (statusCode != null) parts.push('Status ' + statusCode);
        if (msg) parts.push(msg);
        if (errors) parts.push('Details: ' + (typeof errors === 'string' ? errors : JSON.stringify(errors)));
        if (parts.length > 0) return parts.join(' — ');
        return JSON.stringify(err);
    }
}
