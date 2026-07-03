import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';

const FIELDS = ['Opportunity.Co_sell_Type__c', 'Opportunity.Solution_Count__c'];
const COSELL_TYPE_IPCOSELL = 'IP Co-sell';

export default class msft_DisplayMessageOnOpportunity extends LightningElement {
    @api recordId;
    showMessage = false;
    wiredOpportunityData;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredOpportunity(result) {
        this.wiredOpportunityData = result;
        if (result.data) {
            const coSellType = getFieldValue(result.data, FIELDS[0]);
            const solutionCount = getFieldValue(result.data, FIELDS[1]);
            this.showMessage = coSellType === COSELL_TYPE_IPCOSELL && (solutionCount == 0 || solutionCount == null);
        } else if (result.error) {
            console.error('Error loading Opportunity:', JSON.stringify(result.error));
        }
    }

    handleRefresh() {
        setTimeout(() => {
            refreshApex(this.wiredOpportunityData)
            .then(() => console.log('UI Refreshed after timeout'))
            .catch(error => console.error('Error refreshing UI:', error));
        }, 2000);
    }

    connectedCallback() {
        this.handleRefresh();
    }
}