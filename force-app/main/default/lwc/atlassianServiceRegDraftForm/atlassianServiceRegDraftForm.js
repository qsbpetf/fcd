import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getPartnerAccounts from '@salesforce/apex/AtlassianDealRegApiPartnerAccounts.getPartnerAccountsStatic';
import getRegistration from '@salesforce/apex/AtlassianDealRegApiRegistrations.getRegistrationStatic';
import createLocalServiceDraft from '@salesforce/apex/AtlassianServiceRegDraftController.createLocalServiceDraft';
import saveDraftPayload from '@salesforce/apex/AtlassianDealRegDraftController.saveDraftPayload';
import updateServiceDraftByRegistrationId from '@salesforce/apex/AtlassianServiceRegDraftController.updateServiceDraftByRegistrationId';
import findSubmissionByRegistrationId from '@salesforce/apex/AtlassianDealRegDraftController.findSubmissionByRegistrationId';
import submitServiceDraft from '@salesforce/apex/AtlassianServiceRegDraftController.submitServiceDraft';
import pollJobStatus from '@salesforce/apex/AtlassianDealRegDraftController.pollJobStatus';
import getSubmissionRecord from '@salesforce/apex/AtlassianDealRegDraftController.getSubmissionRecord';

const PLATFORM_OPTIONS = [
    { label: 'Cloud', value: 'CLOUD' },
    { label: 'Data Center', value: 'DATA_CENTER' },
    { label: 'Both', value: 'BOTH' }
];

const SOLUTION_OPTIONS = [
    { label: '-- Select --', value: '' },
    { label: 'Enterprise Strategy and Planning', value: 'ENTERPRISE_STRATEGY_AND_PLANNING' },
    { label: 'Cloud Migration', value: 'CLOUD_MIGRATION' },
    { label: 'Service Management', value: 'SERVICE_MANAGEMENT' },
    { label: 'Software Development', value: 'SOFTWARE_DEVELOPMENT' },
    { label: 'Teamwork Foundations', value: 'TEAMWORK_FOUNDATIONS' },
    { label: 'Other', value: 'OTHER' }
];

const REGION_OPTIONS = [
    { label: 'APAC', value: 'APAC' },
    { label: 'AMER', value: 'AMER' },
    { label: 'EMEA', value: 'EMEA' }
];

const SERVICE_TYPE_OPTIONS = [
    { label: 'Cloud Migration and Expansion', value: 'CLOUD_MIGRATION_AND_EXPANSION' },
    { label: 'Configuration and Administration', value: 'CONFIGURATION_AND_ADMINISTRATION' },
    { label: 'Partner Solution Consulting Architecture', value: 'PARTNER_SOLUTION_CONSULTING_ARCHITECTURE' },
    { label: 'Product Implementation', value: 'PRODUCT_IMPLEMENTATION' },
    { label: 'Project Support and Maintenance Support Services', value: 'PROJECT_SUPPORT_AND_MAINTENANCE_SUPPORT_SERVICES' },
    { label: 'Training', value: 'TRAINING' },
    { label: 'Other', value: 'OTHER' }
];

const SERVICE_ENGAGEMENT_STAGE_OPTIONS = [
    { label: '-- Select --', value: '' },
    { label: 'Delivery Not Started', value: 'DELIVERY_NOT_STARTED' },
    { label: 'Delivery In Progress', value: 'DELIVERY_IN_PROGRESS' },
    { label: 'Delivery Completed', value: 'DELIVERY_COMPLETED' }
];

const ENTITY_TYPE_OPTIONS = [
    { label: '-- Select --', value: '' },
    { label: 'Opportunity Number', value: 'OPPORTUNITY_NUMBER' },
    { label: 'SEN', value: 'SEN' },
    { label: 'Order Number', value: 'ORDER_NUMBER' },
    { label: 'Invoice ID', value: 'INVOICE_ID' },
    { label: 'Entitlement Number', value: 'ENTITLEMENT_NUMBER' },
    { label: 'Deal Registration ID', value: 'DEAL_REGISTRATION_ID' }
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
    { label: 'Jira Software', value: 'JIRA_SOFTWARE' },
    { label: 'Jira Software Management', value: 'JIRA_SOFTWARE_MANAGEMENT' },
    { label: 'Jira Work Management', value: 'JIRA_WORK_MANAGEMENT' },
    { label: 'Jira Work Management Expansion Only', value: 'JIRA_WORK_MANAGEMENT_EXPANSION_ONLY' },
    { label: 'Loom', value: 'LOOM' },
    { label: 'Opsgenie', value: 'OPSGENIE' },
    { label: 'Rovo', value: 'ROVO' },
    { label: 'Sourcetree', value: 'SOURCETREE' },
    { label: 'Statuspage', value: 'STATUSPAGE' },
    { label: 'Strategy Collection', value: 'STRATEGY_COLLECTION' },
    { label: 'Teamwork Collection', value: 'TEAMWORK_COLLECTION' },
    { label: 'Trello', value: 'TRELLO' },
    { label: 'Service Collection', value: 'SERVICE_COLLECTION' }
];

const IMMUTABLE_STATUSES = new Set(['APPROVED', 'EXPIRED', 'CLOSED_WON', 'CLOSED_LOST', 'CLOSED', 'REJECTED']);

export default class AtlassianServiceRegDraftForm extends NavigationMixin(LightningElement) {
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
    solution = '';
    regions = [];
    departments = '';
    serviceType = [];
    serviceEngagementStage = '';
    serviceStartDate = '';
    serviceEndDate = '';
    deliveryConsultant = '';
    deliveryConsultantEmail = '';
    userCount = '';
    entityType = '';
    entityIds = '';

    platformOptions = PLATFORM_OPTIONS;
    solutionOptions = SOLUTION_OPTIONS;
    regionOptions = REGION_OPTIONS;
    serviceTypeOptions = SERVICE_TYPE_OPTIONS;
    serviceEngagementStageOptions = SERVICE_ENGAGEMENT_STAGE_OPTIONS;
    entityTypeOptions = ENTITY_TYPE_OPTIONS;
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
        return this.isCreateMode ? 'Create Service Draft' : 'Edit Service Draft';
    }

    get saveButtonLabel() {
        return this.isCreateMode ? 'Create' : 'Save';
    }

    get productsValue() {
        return this.products && this.products.length > 0 ? this.products : [];
    }

    get regionsValue() {
        return this.regions && this.regions.length > 0 ? this.regions : [];
    }

    get serviceTypeValue() {
        return this.serviceType && this.serviceType.length > 0 ? this.serviceType : [];
    }

    submissionStatus = '';
    submissionJobId = '';
    _resolvedRecordId = null;

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
                    programType: 'SERVICE_REGISTRATION'
                });
                this._populateFromRegistration(reg);
            } else if (sub.Draft_Payload_JSON__c) {
                try {
                    const reg = JSON.parse(sub.Draft_Payload_JSON__c);
                    this._populateFromRegistration(reg);
                } catch (parseE) {
                    this.hasError = true;
                    this.errorMessage = 'Could not load saved draft data';
                }
            }
        } catch (err) {
            this.hasError = true;
            this.errorMessage = this._extractError(err);
        } finally {
            this.isLoading = false;
        }
    }

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
                programType: 'SERVICE_REGISTRATION'
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
        this.solution = reg.solution || '';
        this.regions = Array.isArray(reg.regions) ? [...reg.regions] : [];
        this.departments = Array.isArray(reg.departments) ? reg.departments.join(', ') : '';
        this.serviceType = Array.isArray(reg.serviceType) ? [...reg.serviceType] : [];
        this.serviceEngagementStage = reg.serviceEngagementStage || '';
        this.serviceStartDate = reg.serviceStartDate || '';
        this.serviceEndDate = reg.serviceEndDate || '';
        this.deliveryConsultant = reg.deliveryConsultant || '';
        this.deliveryConsultantEmail = reg.deliveryConsultantEmail || '';
        this.userCount = reg.userCount != null ? String(reg.userCount) : '';
        this.entityType = reg.entityType || '';
        this.entityIds = Array.isArray(reg.entityIds) ? reg.entityIds.join(', ') : '';
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

    handleProductsChange(event) {
        const val = event.detail.value;
        this.products = typeof val === 'string' ? (val ? val.split(',') : []) : (Array.isArray(val) ? val : []);
    }

    handleRegionsChange(event) {
        const val = event.detail.value;
        this.regions = typeof val === 'string' ? (val ? val.split(',') : []) : (Array.isArray(val) ? val : []);
    }

    handleServiceTypeChange(event) {
        const val = event.detail.value;
        this.serviceType = typeof val === 'string' ? (val ? val.split(',') : []) : (Array.isArray(val) ? val : []);
    }

    _parseCommaList(str) {
        if (!str || typeof str !== 'string') return [];
        return str.split(',').map((s) => s.trim()).filter(Boolean);
    }

    _buildPayload() {
        const payload = {};
        if (this.parentRegistrationId) payload.parentRegistrationId = this.parentRegistrationId;
        if (this.dealName) payload.dealName = this.dealName;
        payload.programType = 'SERVICE_REGISTRATION';
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
        if (this.solution) payload.solution = this.solution;
        if (this.regions && this.regions.length > 0) payload.regions = [...this.regions];
        const deptList = this._parseCommaList(this.departments);
        if (deptList.length > 0) payload.departments = deptList;
        if (this.serviceType && this.serviceType.length > 0) payload.serviceType = [...this.serviceType];
        if (this.serviceEngagementStage) payload.serviceEngagementStage = this.serviceEngagementStage;
        if (this.serviceStartDate) payload.serviceStartDate = this.serviceStartDate;
        if (this.serviceEndDate) payload.serviceEndDate = this.serviceEndDate;
        if (this.deliveryConsultant) payload.deliveryConsultant = this.deliveryConsultant;
        if (this.deliveryConsultantEmail) payload.deliveryConsultantEmail = this.deliveryConsultantEmail;
        if (this.userCount) payload.userCount = parseFloat(this.userCount) || undefined;
        if (this.entityType) payload.entityType = this.entityType;
        const entityList = this._parseCommaList(this.entityIds);
        if (entityList.length > 0) payload.entityIds = entityList;
        return JSON.stringify(payload);
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
        createLocalServiceDraft({ partnerAccountId: this.selectedPartnerId, body: this._buildPayload() })
            .then((result) => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Registration saved locally. Open the record to sync to Atlassian when ready.', variant: 'success' }));
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: result.recordId, objectApiName: 'AtlassianRegSubmission__c', actionName: 'view' }
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
            ? saveDraftPayload({ recordId, body: this._buildPayload() })
            : updateServiceDraftByRegistrationId({
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
        submitServiceDraft({ recordId: this._effectiveRecordId })
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
