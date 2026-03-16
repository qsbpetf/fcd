import { LightningElement } from 'lwc';
import getPartnerAccounts from '@salesforce/apex/AtlassianDealRegApiPartnerAccounts.getPartnerAccountsStatic';
import searchRegistrations from '@salesforce/apex/AtlassianDealRegApiRegistrations.searchRegistrationsStatic';

const STATUS_OPTIONS = [
    { label: 'Draft', value: 'DRAFT' },
    { label: 'Use Child Registrations', value: 'USE_CHILD_REGISTRATIONS' },
    { label: 'Submitted', value: 'SUBMITTED' },
    { label: 'Approved', value: 'APPROVED' },
    { label: 'Rejected', value: 'REJECTED' },
    { label: 'Closed Won', value: 'CLOSED_WON' },
    { label: 'Closed Lost', value: 'CLOSED_LOST' },
    { label: 'Closed', value: 'CLOSED' },
    { label: 'Returned', value: 'RETURNED' },
    { label: 'Field Approved', value: 'FIELD_APPROVED' },
    { label: 'On Hold', value: 'ON_HOLD' },
    { label: 'Expired', value: 'EXPIRED' },
    { label: 'Pending', value: 'PENDING' },
    { label: 'Under Review', value: 'UNDER_REVIEW' }
];

const PROGRAM_TYPE_OPTIONS = [
    { label: '-- All --', value: '' },
    { label: 'Deal Registration', value: 'DEAL_REGISTRATION' },
    { label: 'Service Registration', value: 'SERVICE_REGISTRATION' }
];

const REGISTRATION_TYPE_OPTIONS = [
    { label: 'Parent', value: 'PARENT' },
    { label: 'Child', value: 'CHILD' }
];

const SORT_BY_OPTIONS = [
    { label: 'Created At', value: 'CREATED_AT' },
    { label: 'Last Modified At', value: 'LAST_MODIFIED_AT' },
    { label: 'Registration ID', value: 'REGISTRATION_ID' },
    { label: 'Status', value: 'STATUS' },
    { label: 'Program Type', value: 'PROGRAM_TYPE' }
];

const SORT_ORDER_OPTIONS = [
    { label: 'Ascending', value: 'ASC' },
    { label: 'Descending', value: 'DESC' }
];

export default class AtlassianRegistrationSearch extends LightningElement {
    partnerOptions = [];
    selectedPartnerId = '';
    selectedStatus = [];
    selectedProgramType = '';
    selectedRegistrationType = '';
    registrationId = '';
    parentRegistrationId = '';
    createdAfter = '';
    createdBefore = '';
    limit = 10;
    selectedSortBy = 'CREATED_AT';
    selectedSortOrder = 'DESC';

    statusOptions = STATUS_OPTIONS;
    programTypeOptions = PROGRAM_TYPE_OPTIONS;
    registrationTypeOptions = REGISTRATION_TYPE_OPTIONS;
    sortByOptions = SORT_BY_OPTIONS;
    sortOrderOptions = SORT_ORDER_OPTIONS;

    isSearching = false;
    hasSearched = false;
    hasError = false;
    errorMessage = '';
    tableData = [];
    nextPageToken = null;
    hasNextPage = false;
    currentPageToken = null;
    previousPageTokenStack = [];
    hasPreviousPage = false;
    showDetailModal = false;

    columns = [
        { label: 'ID', type: 'action', typeAttributes: { rowActions: { fieldName: 'rowActions' } } },
        { label: 'Deal Name', fieldName: 'dealName', type: 'text', wrapText: true },
        { label: 'Program Type', fieldName: 'programType', type: 'text' },
        { label: 'Status', fieldName: 'status', type: 'text' },
        { label: 'Customer Domain', fieldName: 'customerDomain', type: 'text' },
        { label: 'Opp Number', fieldName: 'partnerSubmittedOpportunityNumber', type: 'text' },
        { label: 'Est. Revenue', fieldName: 'estimatedRevenue', type: 'currency', typeAttributes: { currencyCode: 'EUR' } },
        { label: 'Expiration', fieldName: 'expirationDate', type: 'date', typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit' } },
        { label: 'Created', fieldName: 'createdAtFormatted', type: 'text' }
    ];

    connectedCallback() {
        this.loadPartnerAccounts();
    }

    loadPartnerAccounts(forceRefresh = false) {
        getPartnerAccounts({ forceRefresh })
            .then((result) => {
                if (result && result.partnerAccounts && result.partnerAccounts.length > 0) {
                    this.partnerOptions = [
                        { label: '-- Select Partner Account --', value: '' },
                        ...result.partnerAccounts.map((acc) => ({
                            label: acc.accountName,
                            value: acc.partnerId
                        }))
                    ];
                } else {
                    this.partnerOptions = [{ label: 'No partner accounts available', value: '' }];
                }
            })
            .catch((error) => {
                this.partnerOptions = [{ label: 'Error loading partners', value: '' }];
                console.error('Error loading partner accounts:', error);
            });
    }

    handlePartnerChange(event) {
        this.selectedPartnerId = event.detail.value;
    }

    handleRefreshPartnerAccounts() {
        this.loadPartnerAccounts(true);
    }
    handleStatusChange(event) {
        this.selectedStatus = event.detail.value || [];
    }
    handleProgramTypeChange(event) {
        this.selectedProgramType = event.detail.value || '';
    }
    handleRegistrationIdChange(event) {
        this.registrationId = event.detail.value;
    }
    handleParentRegistrationIdChange(event) {
        this.parentRegistrationId = event.detail.value;
    }
    handleRegistrationTypeChange(event) {
        this.selectedRegistrationType = event.detail.value;
    }
    handleCreatedAfterChange(event) {
        this.createdAfter = event.detail.value;
    }
    handleCreatedBeforeChange(event) {
        this.createdBefore = event.detail.value;
    }
    handleLimitChange(event) {
        const val = parseInt(event.detail.value, 10);
        this.limit = isNaN(val) ? 10 : Math.min(100, Math.max(1, val));
    }
    handleSortByChange(event) {
        this.selectedSortBy = event.detail.value;
    }
    handleSortOrderChange(event) {
        this.selectedSortOrder = event.detail.value;
    }

    get hasResults() {
        return this.tableData && this.tableData.length > 0;
    }

    handleRowAction(event) {
        const action = event.detail?.action?.name;
        const row = event.detail?.row;
        if (action === 'view' && row && this.selectedPartnerId) {
            this.showDetailModal = true;
            this._detailRegistrationId = row.id;
            this._detailPartnerId = this.selectedPartnerId;
            this._detailProgramType = this.normalizeProgramType(row.programType) || 'DEAL_REGISTRATION';
        }
    }

    handleCloseDetailModal() {
        this.showDetailModal = false;
        this._detailRegistrationId = null;
        this._detailPartnerId = null;
        this._detailProgramType = null;
    }

    handleSearch() {
        if (!this.selectedPartnerId) {
            return;
        }
        this.nextPageToken = null;
        this.previousPageTokenStack = [];
        this.performSearch(null);
    }

    handleNextPage() {
        if (this.nextPageToken) {
            this.previousPageTokenStack.push(this.currentPageToken);
            this.performSearch(this.nextPageToken);
        }
    }

    handlePreviousPage() {
        if (this.previousPageTokenStack.length > 0) {
            const token = this.previousPageTokenStack.pop();
            this.performSearch(token);
        }
    }

    performSearch(pageToken) {
        this.isSearching = true;
        this.hasSearched = true;
        this.hasError = false;
        this.errorMessage = '';

        const statusStr = Array.isArray(this.selectedStatus) && this.selectedStatus.length > 0
            ? this.selectedStatus.join(',')
            : null;
        const programTypeStr = (() => {
            const v = this.selectedProgramType;
            if (!v) return null;
            if (Array.isArray(v) && v.length > 0) return v.join(',');
            const s = String(v).trim();
            return s ? s : null;
        })();

        const limitVal = this.limit && this.limit >= 1 && this.limit <= 100 ? this.limit : 10;

        console.log('performSearch partnerAccountId:', this.selectedPartnerId);
        console.log('performSearch status:', statusStr);
        console.log('performSearch registrationId:', this.registrationId);
        console.log('performSearch parentRegistrationId:', this.parentRegistrationId);
        console.log('performSearch programType:', programTypeStr);
        console.log('performSearch registrationType:', this.selectedRegistrationType);
        console.log('performSearch createdAfter:', this.createdAfter);
        console.log('performSearch createdBefore:', this.createdBefore);
        console.log('performSearch limit:', limitVal);
        console.log('performSearch pageToken:', pageToken !== undefined ? pageToken : (this.nextPageToken || null));
        console.log('performSearch sortBy:', this.selectedSortBy);
        console.log('performSearch sortOrder:', this.selectedSortOrder);

        searchRegistrations({
            partnerAccountId: this.selectedPartnerId,
            status: statusStr,
            registrationId: this.registrationId || null,
            parentRegistrationId: this.parentRegistrationId || null,
            programType: programTypeStr,
            registrationType: this.selectedRegistrationType || null,
            createdAfter: this.createdAfter || null,
            createdBefore: this.createdBefore || null,
            pageSize: limitVal,
            pageToken: pageToken !== undefined ? pageToken : (this.nextPageToken || null),
            sortBy: this.selectedSortBy || null,
            sortOrder: this.selectedSortOrder || null
        })
            .then((result) => {
                const filtered = this.applyClientSideProgramTypeFilter(result.registrations);
                this.tableData = this.prepareTableData(filtered);
                this.currentPageToken = pageToken !== undefined ? pageToken : null;
                this.nextPageToken = result.pagination?.nextPageToken ?? null;
                this.hasNextPage = result.pagination?.hasNext ?? false;
                this.hasPreviousPage = (result.pagination?.hasPrevious ?? false) || this.previousPageTokenStack.length > 0;
                this.isSearching = false;
            })
            .catch((error) => {
                this.isSearching = false;
                this.hasError = true;
                this.errorMessage = this.extractErrorMessage(error);
            });
    }

    normalizeProgramType(value) {
        if (!value) return '';
        return (value || '').replace(/\s+/g, '_').toUpperCase();
    }

    applyClientSideProgramTypeFilter(registrations) {
        if (!registrations || registrations.length === 0) return [];
        const selected = this.selectedProgramType;
        const selectedArr = !selected ? [] : Array.isArray(selected) ? selected : [selected];
        if (selectedArr.length === 0) return registrations;
        const allowed = new Set(selectedArr.map((v) => this.normalizeProgramType(v)));
        return registrations.filter((r) => {
            const pt = this.normalizeProgramType(r.programType);
            console.log('  applyClientSideProgramTypeFilter pt:', pt, 'allowed:', allowed, 'filtered:', pt && allowed.has(pt));
            return pt && allowed.has(pt);
        });
    }

    prepareTableData(registrations) {
        if (!registrations || registrations.length === 0) {
            return [];
        }
        return registrations.map((r) => {
            const rev = r.estimatedRevenue;
            const estimatedRevenueNum = rev == null || rev === '' ? null : (typeof rev === 'number' ? rev : parseFloat(String(rev)));
            return {
                ...r,
                rowActions: [{ label: r.id || '', name: 'view' }],
                estimatedRevenue: isNaN(estimatedRevenueNum) ? null : estimatedRevenueNum,
                createdAtFormatted: r.createdAt ? this.formatDateTime(r.createdAt) : ''
            };
        });
    }

    formatDateTime(isoStr) {
        if (!isoStr) return '';
        try {
            const d = new Date(isoStr);
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, '0');
            const day = String(d.getDate()).padStart(2, '0');
            const h = String(d.getHours()).padStart(2, '0');
            const min = String(d.getMinutes()).padStart(2, '0');
            const sec = String(d.getSeconds()).padStart(2, '0');
            return `${y}-${m}-${day} ${h}:${min}:${sec}`;
        } catch {
            return isoStr;
        }
    }

    extractErrorMessage(error) {
        if (!error) return 'An unknown error occurred.';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}
