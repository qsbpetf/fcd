import { LightningElement, api, wire } from 'lwc';
import getActivePromoCodes from '@salesforce/apex/PromoCodeController.getActivePromoCodes';

export default class ActivePromos extends LightningElement {
    @api recordId;
    partnerName = null;
    promoCodes = [];
    error;

    columns = [
        { label: 'Promo Code', fieldName: 'PromoCode__c', type: 'text' },
        { label: 'Start Date', fieldName: 'StartDate__c', type: 'date' },
        { label: 'End Date', fieldName: 'EndDate__c', type: 'date' },
        { label: 'Partner', fieldName: 'Partner__c', type: 'text' }
    ];

    @wire(getActivePromoCodes, { partnerName: '$partnerName' })
    wiredPromoCodes({ error, data }) {
        if (data) {
            this.promoCodes = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.promoCodes = [];
        }
    }

    get hasPromoCodes() {
        return this.promoCodes && this.promoCodes.length > 0;
    }
}