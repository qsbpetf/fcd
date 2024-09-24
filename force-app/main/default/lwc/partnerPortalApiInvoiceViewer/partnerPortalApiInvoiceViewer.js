/**
 * Created by peterfriberg on 2024-08-15.
 */

import { api, LightningElement, track } from 'lwc';
import apexGetInvoices from '@salesforce/apex/PortalCommerceApiController.getInvoices';

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
        apexGetInvoices({ accountId: this.recordId })
            .then(result => {
                console.log('result', result);
                this.invoiceResults = this.prepare(result);
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

    prepare(result) {
        let totalList = {
            data: [],
            error: ''
        };
        result.forEach(invoiceList => {
            invoiceList.data.forEach(invoice => {
                invoice.length = invoice.items.length;
            });
            if (invoiceList.missingAccountId && (invoiceList.error === undefined || invoiceList.error === null || invoiceList.error === '')) {
                invoiceList.error = this.errorMessage;
            }
            if (invoiceList.data.length === 0) {
                invoiceList.error = 'No invoices found';
            }
            totalList.data = totalList.data.concat(invoiceList.data);
            totalList.error = totalList.error + '; ' + invoiceList.error;
        });
        return totalList;
    }
}