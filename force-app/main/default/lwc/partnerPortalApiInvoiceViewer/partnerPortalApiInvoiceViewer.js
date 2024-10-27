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

                invoice.items.forEach(item => {
                    item.subTotalDecimal = item.subTotal;
                    item.totalDecimal = item.total;
                    item.startAt = item.period.startAt;
                    item.startAtStr= new Date(item.period.startAt).toLocaleDateString(
                        'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
                    item.endAt = item.period.endAt;
                    item.endAtStr = new Date(item.period.endAt).toLocaleDateString(
                        'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
                    item.discountAmount = (item.margins && item.margins.length > 0) ? item.margins[0].amount : null;
                });
            });
            if (invoiceList.missingAccountId && (invoiceList.error === undefined || invoiceList.error === null || invoiceList.error === '')) {
                invoiceList.error = this.errorMessage;
                totalList.missingAccountId = true;
            }
            if (invoiceList.missingAccountId && invoiceList.error) {
                totalList.missingAccountId = true;
            }
            if (!invoiceList.missingAccountId && invoiceList.data.length === 0) {
                invoiceList.error = 'No invoices found';
                totalList.missingAccountId = true;
            }
            totalList.data = totalList.data.concat(invoiceList.data);
            totalList.error = totalList.error + '; ' + invoiceList.error;
        });
        return totalList;
    }
}