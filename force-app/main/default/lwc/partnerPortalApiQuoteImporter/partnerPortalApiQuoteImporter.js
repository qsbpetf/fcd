/**
 * Created by peterfriberg on 2024-08-13.
 */

import { api, track, LightningElement } from 'lwc';
import apexConvertQuote from '@salesforce/apex/PortalCommerceApiController.getQuotes';
import apexImportQuote from '@salesforce/apex/PortalCommerceApiController.importQuote';

export default class PartnerPortalApiQuoteImporter extends LightningElement {

    @api recordId;
    @api errorMessage;

    @track quoteResults = {
        data: [],
        nextId: null
    };

    @track selectedItem = { id: '' }; // Used to store the clicked row data handleRowClick(event) {
    @track content;

    isLoading = true;
    columns = [
        { label: 'Quote Number', fieldName: 'quoteNumber', type: 'text' },
        { label: '# Items', fieldName: 'length', type: 'number' },
        { label: 'Status', fieldName: 'status', type: 'text',
            cellAttributes: {
                class: { fieldName: 'statusClass' }
            }
        },
        { label: 'Created Date', fieldName: 'createdDate', type: 'text' },
        { label: 'Expire Date', fieldName: 'expireDate', type: 'text' },
        { label: 'Description', fieldName: 'description', type: 'text' },
        { label: 'Quantity', fieldName: 'quantity', type: 'number' },
        {
            label: 'Subtotal',
            fieldName: 'subTotal',
            type: 'currency',
            typeAttributes: {
                currencyCode: { fieldName: 'isoCurrency' }
            }
        },
        {
            label: 'Total',
            fieldName: 'total',
            type: 'currency',
            typeAttributes: {
                currencyCode: { fieldName: 'isoCurrency' }
            }
        },
        {
            type: 'button',
            label: 'Import',
            typeAttributes: {
                iconName: 'utility:download',
                name: 'download',
                label: { fieldName: 'action' },
                title: { fieldName: 'action' },
                variant: 'bare'
            },
            initialWidth: 120
        }
    ];

    connectedCallback() {
        console.log('connectedCallback', this.recordId);
        debugger;
        this.getQuotes();
    }

    // Method to handle the row action
    handleRowAction(event) {
        this.selectedItem = event.detail.row;
        const action = event.detail.action;
        console.log('Action: ', action.label);
        console.log('Selected Row: ', this.selectedItem, JSON.stringify(this.selectedItem, null, 2));
        this.content = JSON.stringify(this.selectedItem, null, 2);

        if (this.selectedItem.level === 1) {
            let choice = confirm('Are you sure you want to import this quote ' + this.selectedItem.quoteNumber + ' ?');
            if (choice) {
                this.importQuote(this.selectedItem);
            }
        }
    }

    importQuote(quote) {
        console.log('importQuote', quote);
        this.isLoading = true;
        apexImportQuote({
            opportunityId: this.recordId,
            quoteInfo: JSON.stringify(quote)
        })
            .then(result => {
                console.log('result', result);
                if (result === 'OK') {
                    alert('*** TESTING ONLY! ***   Quote ' + quote.quoteNumber + ' imported successfully!');
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.error('error', error);
                this.isLoading = false;
            });
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
                if (error.status && error.status === 500) {
                    this.quoteResults.error = error.body.exceptionType + ': ' + error.body.message;
                }
            });
    }

    calculate(result) {
        result.data.forEach(quote => {
            quote.length = quote.upcomingBills.lines.length;
            // convert unix time milliseconds since epoch to Date object
            quote.createdDate = new Date(quote.createdAt).toLocaleDateString(
                'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
            quote.expireDate = new Date(quote.expiresAt).toLocaleDateString(
                'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
            quote.statusClass = quote.status.includes('ACCEPTED') ? 'slds-text-color_success' : quote.status.includes('CANCELLED') ? 'slds-text-color_error' : '';
            quote._children = [];
            quote.upcomingBills.lines.forEach(item => {
                quote._children.push({
                    id: item.id,
                    description: item.description,
                    quantity: item.quantity,
                    subTotal: item.subTotal,
                    total: item.total,
                    isoCurrency: item.isoCurrency
                });
            });
        });
        if (result.missingAccountId && (result.error === undefined || result.error === null || result.error === '')) {
            result.error = this.errorMessage;
        }
        return result;
    }
}