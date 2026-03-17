import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import PROGRAM_TYPE_FIELD from '@salesforce/schema/AtlassianRegSubmission__c.Program_Type__c';

const PROGRAM_TYPE_DEAL = 'DEAL_REGISTRATION';
const PROGRAM_TYPE_SERVICE = 'SERVICE_REGISTRATION';

export default class AtlassianRegEditButton extends LightningElement {
    @api recordId;

    programType = '';
    showModal = false;

    @wire(getRecord, { recordId: '$recordId', fields: [PROGRAM_TYPE_FIELD] })
    wiredRecord({ data, error }) {
        if (data) {
            this.programType = getFieldValue(data, PROGRAM_TYPE_FIELD) || '';
        }
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

    get showServicePlaceholder() {
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
