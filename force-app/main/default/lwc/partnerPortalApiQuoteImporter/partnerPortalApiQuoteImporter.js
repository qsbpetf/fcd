/**
 * Created by peterfriberg on 2024-08-13.
 */

import { api, track, LightningElement } from 'lwc';
import apexConvertQuote from '@salesforce/apex/PortalCommerceApiController.getQuotes';

export default class PartnerPortalApiQuoteImporter extends LightningElement {

    @api recordId;
    @api errorMessage;

    isLoading = true;

    @track quoteResults = {
        data: [],
        nextId: null
    };

    connectedCallback() {
        console.log('connectedCallback', this.recordId);
        debugger;
        this.getQuotes();
    }

    getQuotes() {
        console.log('getQuotes', this.recordId);
        this.isLoading = true;
        apexConvertQuote({ opportunityId: this.recordId })
            .then(result => {
                console.log('result', result);
                this.quoteResults = this.calculate(result);
                this.isLoading = false;
            })
            .catch(error => {
                console.error('error', error);
                this.isLoading = false;
                this.quoteResults = {
                    error: JSON.stringify(error),
                    data: [],
                    nextId: null,
                    missingAccountId: true
                };
            });
    }

    calculate(result) {
        result.data.forEach(quote => {
            quote.length = quote.upcomingBills.lines.length;
        });
        if (result.missingAccountId && (result.error === undefined || result.error === null || result.error === '')) {
            result.error = this.errorMessage;
        }
        return result;
    }
}