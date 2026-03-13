import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPartnerAccounts from '@salesforce/apex/AtlassianDealRegApiPartnerAccounts.getPartnerAccountsStatic';

export default class AtlassianPartnerAccounts extends LightningElement {
    isLoading = true;
    hasError = false;
    errorMessage = '';
    displayAccounts = [];

    connectedCallback() {
        this.loadPartnerAccounts();
    }

    get hasAccounts() {
        return this.displayAccounts && this.displayAccounts.length > 0;
    }

    loadPartnerAccounts() {
        this.isLoading = true;
        this.hasError = false;
        this.errorMessage = '';

        getPartnerAccounts()
            .then((result) => {
                this.displayAccounts = this.prepareAccounts(result);
                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;
                this.hasError = true;
                this.errorMessage = this.extractErrorMessage(error);
            });
    }

    prepareAccounts(result) {
        if (!result || !result.partnerAccounts) {
            return [];
        }
        return result.partnerAccounts.map((acc) => ({
            ...acc,
            roleItems: acc.roles && acc.roles.length > 0 ? acc.roles : ['—']
        }));
    }

    extractErrorMessage(error) {
        if (!error) return 'An unknown error occurred.';
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }

    handleRefresh() {
        this.loadPartnerAccounts();
    }

    handleCopyPartnerId(event) {
        const partnerId = event.currentTarget.dataset.partnerId;
        if (partnerId && navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(partnerId).then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copied',
                    message: 'Partner ID copied to clipboard',
                    variant: 'success'
                }));
            });
        }
    }
}
