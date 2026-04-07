import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import STATUS_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Status__c';
import PROGRAM_TYPE_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Program_Type__c';
import JOB_ID_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Job_Id__c';
import REGISTRATION_ID_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Registration_Id__c';
import submitDealDraft from '@salesforce/apex/AtlassianDealRegDraftController.submitDealDraft';
import submitServiceDraft from '@salesforce/apex/AtlassianServiceRegDraftController.submitServiceDraft';
import pollJobStatus from '@salesforce/apex/AtlassianDealRegDraftController.pollJobStatus';
import syncDraftToAtlassian from '@salesforce/apex/AtlassianDealRegDraftController.syncDraftToAtlassian';

const STATUS_DRAFT = 'DRAFT';
const REFRESH_STATUSES = new Set(['IN_PROGRESS', 'COMPLETED', 'FAILED', 'VALIDATION_ERROR']);

function normalizeStatus(value) {
    return (value || '').toUpperCase().replace(/\s+/g, '_');
}

export default class AtlassianRegSubmitRefreshButton extends LightningElement {
    @api recordId;

    status = '';
    programType = '';
    jobId = '';
    registrationId = '';
    isSubmitting = false;
    isRefreshing = false;
    isSyncing = false;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [STATUS_FIELD, PROGRAM_TYPE_FIELD, JOB_ID_FIELD, REGISTRATION_ID_FIELD]
    })
    wiredRecord({ data }) {
        if (data) {
            this.status = normalizeStatus(getFieldValue(data, STATUS_FIELD));
            this.programType = (getFieldValue(data, PROGRAM_TYPE_FIELD) || '').toUpperCase();
            this.jobId = getFieldValue(data, JOB_ID_FIELD) || '';
            this.registrationId = (getFieldValue(data, REGISTRATION_ID_FIELD) || '').trim();
        }
    }

    get showSyncButton() {
        return !this.registrationId;
    }

    get showSubmitButton() {
        return !!this.registrationId && this.status === STATUS_DRAFT;
    }

    get showRefreshButton() {
        return REFRESH_STATUSES.has(this.status);
    }

    handleSync() {
        if (!this.recordId) return;
        this.isSyncing = true;

        syncDraftToAtlassian({ recordId: this.recordId })
            .then((result) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Created in Atlassian',
                        message: 'Registration ID: ' + (result.registrationId || ''),
                        variant: 'success'
                    })
                );
                this._notifyRecordChange();
            })
            .catch((err) => {
                const msg = this._extractError(err);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: msg,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isSyncing = false;
            });
    }

    handleSubmit() {
        if (!this.recordId) return;
        this.isSubmitting = true;

        const submitMethod = this.programType === 'SERVICE_REGISTRATION' ? submitServiceDraft : submitDealDraft;

        submitMethod({ recordId: this.recordId })
            .then((result) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Submitted',
                        message: 'Registration submitted. Job ID: ' + (result.jobId || ''),
                        variant: 'success'
                    })
                );
                this._notifyRecordChange();
            })
            .catch((err) => {
                const msg = this._extractError(err);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: msg,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    handleRefresh() {
        if (!this.recordId) return;
        if (!this.jobId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No job ID to refresh. Submit the registration first.',
                    variant: 'error'
                })
            );
            return;
        }
        this.isRefreshing = true;

        pollJobStatus({ recordId: this.recordId })
            .then((result) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Refreshed',
                        message: 'Status: ' + (result.status || ''),
                        variant: 'success'
                    })
                );
                this._notifyRecordChange();
            })
            .catch((err) => {
                const msg = this._extractError(err);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: msg,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isRefreshing = false;
            });
    }

    _notifyRecordChange() {
        getRecordNotifyChange([{ recordId: this.recordId }]);
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
        return err.message || JSON.stringify(err);
    }
}
