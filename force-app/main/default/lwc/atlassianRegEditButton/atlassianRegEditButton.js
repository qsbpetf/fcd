import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import PROGRAM_TYPE_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Program_Type__c';
import STATUS_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Status__c';

const PROGRAM_TYPE_SERVICE = 'SERVICE_REGISTRATION';
const STATUS_DRAFT = 'DRAFT';

export default class AtlassianRegEditButton extends LightningElement {
    @api recordId;

    programType = '';
    status = '';
    showModal = false;

    @wire(getRecord, { recordId: '$recordId', fields: [PROGRAM_TYPE_FIELD, STATUS_FIELD] })
    wiredRecord({ data }) {
        if (data) {
            this.programType = getFieldValue(data, PROGRAM_TYPE_FIELD) || '';
            this.status = getFieldValue(data, STATUS_FIELD) || '';
        }
    }

    get isEditDisabled() {
        return this.status.toUpperCase() !== STATUS_DRAFT;
    }

    get modalTitle() {
        if (this.programType === PROGRAM_TYPE_SERVICE) {
            return 'Edit Service Registration';
        }
        return 'Edit Deal Registration';
    }

    get showDealForm() {
        return this.showModal && this.programType !== PROGRAM_TYPE_SERVICE;
    }

    get showServiceForm() {
        return this.showModal && this.programType === PROGRAM_TYPE_SERVICE;
    }

    handleOpenModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleFormUpdated() {
        this.showModal = false;
        window.location.reload();
    }
}
