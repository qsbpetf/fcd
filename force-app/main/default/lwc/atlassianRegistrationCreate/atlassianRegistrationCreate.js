import { LightningElement } from 'lwc';

const REGISTRATION_TYPE_DEAL = 'DEAL_REGISTRATION';
const REGISTRATION_TYPE_SERVICE = 'SERVICE_REGISTRATION';

export default class AtlassianRegistrationCreate extends LightningElement {
    registrationTypeOptions = [
        { label: '-- Select registration type --', value: '' },
        { label: 'Deal Registration', value: REGISTRATION_TYPE_DEAL },
        { label: 'Service Registration', value: REGISTRATION_TYPE_SERVICE }
    ];

    selectedRegistrationType = '';

    get showDealForm() {
        return this.selectedRegistrationType === REGISTRATION_TYPE_DEAL;
    }

    get showServiceForm() {
        return this.selectedRegistrationType === REGISTRATION_TYPE_SERVICE;
    }

    get showFormContent() {
        return this.showDealForm || this.showServiceForm;
    }

    handleRegistrationTypeChange(event) {
        this.selectedRegistrationType = event.detail.value || '';
    }
}
