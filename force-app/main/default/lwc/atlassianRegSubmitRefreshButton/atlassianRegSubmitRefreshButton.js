import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import STATUS_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Status__c';
import PROGRAM_TYPE_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Program_Type__c';
import JOB_ID_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Job_Id__c';
import submitDealDraft from '@salesforce/apex/AtlassianDealRegDraftController.submitDealDraft';
import submitServiceDraft from '@salesforce/apex/AtlassianServiceRegDraftController.submitServiceDraft';
import pollJobStatus from '@salesforce/apex/AtlassianDealRegDraftController.pollJobStatus';

const STATUS_DRAFT = 'DRAFT';
const REFRESH_STATUSES = new Set(['IN PROGRESS', 'COMPLETED', 'FAILED', 'VALIDATION ERROR']);

export default class AtlassianRegSubmitRefreshButton extends LightningElement {
    @api recordId;

    status = '';
    programType = '';
    jobId = '';
    isSubmitting = false;
    isRefreshing = false;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [STATUS_FIELD, PROGRAM_TYPE_FIELD, JOB_ID_FIELD]
    })
    wiredRecord({ data }) {
        if (data) {
            this.status = (getFieldValue(data, STATUS_FIELD) || '').toUpperCase();
            this.programType = (getFieldValue(data, PROGRAM_TYPE_FIELD) || '').toUpperCase();
            this.jobId = getFieldValue(data, JOB_ID_FIELD) || '';
        }
    }

    get showSubmitButton() {
        return this.status === STATUS_DRAFT;
    }

    get showRefreshButton() {
        return REFRESH_STATUSES.has(this.status);
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
