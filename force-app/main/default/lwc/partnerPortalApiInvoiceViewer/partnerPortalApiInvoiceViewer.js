/**
 * Created by peterfriberg on 2024-08-15.
 */

import { api, LightningElement, track } from 'lwc';
import apexConvertInvoice from '@salesforce/apex/PortalCommerceApiController.getInvoices';

export default class PartnerPortalApiInvoiceViewer extends LightningElement {

    @api recordId;
    @api errorMessage;

    isLoading = true;

    @track invoiceResults = {
        data: [],
        nextId: null
    };

    connectedCallback() {
        console.log('connectedCallback', this.recordId);
        debugger;
        this.getInvoices();
    }

    getInvoices() {
        console.log('getInvoices', this.recordId);
        this.isLoading = true;
        apexConvertInvoice({ accountId: this.recordId })
            .then(result => {
                console.log('result', result);
                this.invoiceResults = this.calculate(result);
                this.isLoading = false;
            })
            .catch(error => {
                console.error('error', error);
                this.isLoading = false;
                this.invoiceResults = {
                    error: JSON.stringify(error),
                    data: [],
                    nextId: null,
                    missingAccountId: true
                };
                if (error.status && error.status === 500) {
                    this.invoiceResults.error = error.body.exceptionType + ': ' + error.body.message;
                }
            });
    }

    calculate(result) {
        result.data.forEach(invoice => {
            invoice.length = invoice.items.length;
        });
        if (result.missingAccountId && (result.error === undefined || result.error === null || result.error === '')) {
            result.error = this.errorMessage;
        }
        if (result.data.length === 0) {
            result.error = 'No invoices found';
        }
        return result;
    }
}