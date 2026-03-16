import { LightningElement, api } from 'lwc';
import getRegistration from '@salesforce/apex/AtlassianDealRegApiRegistrations.getRegistrationStatic';

const CORE_FIELDS = [
    'id',
    'dealName',
    'parentRegistrationId',
    'programType',
    'status',
    'submissionDate',
    'expirationDate',
    'approvalDate',
    'createdAt',
    'lastModifiedAt'
];

const CUSTOMER_FIELDS = ['customerDomain', 'customerContactEmailId'];

const PARTNER_FIELDS = [
    'partnerSalesRepresentativeEmailId',
    'partnerSubmittedOpportunityNumber',
    'opportunityNumber'
];

const REVENUE_FIELDS = ['estimatedRevenue'];

const DATE_TIME_FIELDS = new Set(['createdAt', 'lastModifiedAt', 'submissionDate', 'expirationDate', 'approvalDate', 'serviceStartDate', 'serviceEndDate', 'estimatedOpportunityCloseDate']);

const KNOWN_FIELDS = new Set([
    ...CORE_FIELDS,
    ...CUSTOMER_FIELDS,
    ...PARTNER_FIELDS,
    ...REVENUE_FIELDS,
    'extensionStatus',
    'denialReason',
    'comments',
    'notes',
    'products',
    'platform',
    'termsAccepted',
    'sowConfirmed',
    'termsConfirmed',
    'detailedDescription',
    'solution',
    'regions',
    'departments',
    'serviceType',
    'serviceEngagementStage',
    'serviceStartDate',
    'serviceEndDate',
    'customerHasCloudSite',
    'cloudSite',
    'estimatedOpportunityCloseDate',
    'dealRegDcExceptionReason',
    'budgetAllocated',
    'salesType',
    'rfpRelated',
    'rfpRelatedTo',
    'additionalInfo',
    'deliveryConsultant',
    'deliveryConsultantEmail',
    'userCount',
    'entityType',
    'entityIds',
    'otherDepartment'
]);

export default class AtlassianRegistrationDetail extends LightningElement {
    @api registrationId;
    @api partnerAccountId;
    @api programType;

    registration = null;
    isLoading = false;
    hasError = false;
    errorMessage = '';

    _coreFields = [];
    _customerFields = [];
    _partnerFields = [];
    _revenueFields = [];
    _additionalFields = [];

    connectedCallback() {
        this.loadFromUrlState();
    }

    loadFromUrlState() {
        const urlParams = new URLSearchParams(window.location.search);
        const regId = this.registrationId || urlParams.get('c__registrationId');
        const partnerId = this.partnerAccountId || urlParams.get('c__partnerAccountId');
        const progType = this.programType || urlParams.get('c__programType');

        if (regId && partnerId) {
            this.fetchRegistration(regId, partnerId, progType);
        }
    }

    @api
    setRegistrationContext(registrationId, partnerAccountId, programType) {
        if (registrationId && partnerAccountId) {
            this.fetchRegistration(registrationId, partnerAccountId, programType);
        }
    }

    fetchRegistration(registrationId, partnerAccountId, programType) {
        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = '';
        this.registration = null;

        getRegistration({
            partnerAccountId,
            registrationId,
            programType: programType || 'DEAL_REGISTRATION'
        })
            .then((data) => {
                this.registration = data;
                this._buildFieldSections(data);
                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;
                this.hasError = true;
                this.errorMessage = this._extractErrorMessage(error);
            });
    }

    _buildFieldSections(data) {
        if (!data || typeof data !== 'object') return;

        this._coreFields = this._pickFields(data, CORE_FIELDS);
        this._customerFields = this._pickFields(data, CUSTOMER_FIELDS);
        this._partnerFields = this._pickFields(data, PARTNER_FIELDS);
        this._revenueFields = this._pickFields(data, REVENUE_FIELDS);

        const additional = [];
        for (const [key, value] of Object.entries(data)) {
            if (value != null && value !== '' && !KNOWN_FIELDS.has(key)) {
                additional.push({
                    key: this._labelFromKey(key),
                    value: this._formatValue(key, value),
                    isDateTime: false,
                    valueClass: 'field-value'
                });
            }
        }
        this._additionalFields = additional;
    }

    _pickFields(data, keys) {
        return keys
            .filter((k) => data[k] != null && data[k] !== '')
            .map((k) => {
                const isId = k === 'id';
                return {
                    key: this._labelFromKey(k),
                    value: this._formatValue(k, data[k]),
                    isDateTime: false,
                    valueClass: isId ? 'field-value field-value-id' : 'field-value'
                };
            });
    }

    _labelFromKey(key) {
        return key
            .replace(/([A-Z])/g, ' $1')
            .replace(/^./, (s) => s.toUpperCase())
            .replace(/_/g, ' ')
            .trim();
    }

    _formatValue(key, value) {
        if (value === null || value === undefined) return '';
        if (typeof value === 'boolean') return value ? 'Yes' : 'No';
        if (Array.isArray(value)) return value.join(', ');
        if (typeof value === 'object') return JSON.stringify(value);
        if (key === 'estimatedRevenue') {
            const num = parseFloat(value);
            return isNaN(num) ? String(value) : new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(num);
        }
        if (DATE_TIME_FIELDS.has(key) && typeof value === 'string') {
            const datePart = value.split('T')[0];
            if (/^\d{4}-\d{2}-\d{2}$/.test(datePart)) return datePart;
        }
        return String(value);
    }

    get coreFields() {
        return this._coreFields;
    }

    get customerFields() {
        return this._customerFields;
    }

    get partnerFields() {
        return this._partnerFields;
    }

    get revenueFields() {
        return this._revenueFields;
    }

    get additionalFields() {
        return this._additionalFields;
    }

    get hasAdditionalFields() {
        return this._additionalFields && this._additionalFields.length > 0;
    }

    get hasRegistration() {
        return this.registration != null && !this.isLoading;
    }

    get showPlaceholder() {
        return !this.registrationId && !this.partnerAccountId && !this.isLoading && !this.hasError;
    }

    _extractErrorMessage(error) {
        if (!error) return 'An unknown error occurred.';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
