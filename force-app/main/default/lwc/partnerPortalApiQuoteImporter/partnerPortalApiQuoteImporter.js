/**
 * Created by peterfriberg on 2024-08-13.
 */

import { api, track, LightningElement } from 'lwc';
import apexConvertQuote from '@salesforce/apex/PortalCommerceApiController.getQuotes';

export default class PartnerPortalApiQuoteImporter extends LightningElement {

    @api recordId;

    isLoading = true;
    buttonsDisabled = true;

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
            });
    }

    calculate(result) {
        result.data.forEach(quote => {
            quote.length = quote.upcomingBills.lines.length;
        });
        return result;
    }
}