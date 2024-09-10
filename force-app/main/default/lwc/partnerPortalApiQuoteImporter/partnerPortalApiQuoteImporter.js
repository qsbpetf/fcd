/**
 * Created by peterfriberg on 2024-08-13.
 */

import { api, track, LightningElement } from 'lwc';
import apexGetQuotes from '@salesforce/apex/PortalCommerceApiController.getQuotes';
import apexGetQuote from '@salesforce/apex/PortalCommerceApiController.getQuote';
import apexImportQuote from '@salesforce/apex/PpcQuoteConverter.convertQuote';
import apexGetEntitlementDisplayInfo from '@salesforce/apex/PortalCommerceApiController.getEntitlementDisplayInfo';
import apexGetEntitlementDetails from '@salesforce/apex/PortalCommerceApiController.getEntitlementDetails';

export default class PartnerPortalApiQuoteImporter extends LightningElement {

    @api recordId;
    @api errorMessage;

    @track quoteResults = {
        data: [],
        nextId: null,
        missingAccountId: false,
        error: ''
    };

    quote = { };

    @track conversionResult = {
        errorLog: [],
        pbeLog: [],
        productLog: [],
        successLog: []
    };

    @track selectedItem = { id: '' }; // Used to store the clicked row data handleRowClick(event) {
    @track content;

    @track quoteUrl;  // Typical URL =

    isLoading = false;
    importDisabled = true;
    quoteLineIds = {};
    lineItems = {};
    entitlementIds = {};

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
                currencyCode: { fieldName: 'isoCurrency' },
                decimalPlaces: '2'
            }
        },
        {
            label: 'Total',
            fieldName: 'total',
            type: 'currency',
            typeAttributes: {
                currencyCode: { fieldName: 'isoCurrency' },
                decimalPlaces: '2'
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
        // this.getQuotes();
    }

    handleQuoteUrlChange(event) {
        this.quoteUrl = event.target.value;
    }

    handleFetchQuote() {
        console.log('getQuote for opp', this.recordId);
        console.log('Parsing quoteUrl', this.quoteUrl);

        if (this.quoteUrl === undefined || this.quoteUrl === null || this.quoteUrl === '') {
            return;
        }

        let parts = this.quoteUrl.split('/');
        let quoteId = parts[parts.length - 1];
        console.log('quoteId', quoteId);

        this.quoteResults = {
            data: [],
            nextId: null,
            missingAccountId: false,
            error: ''
        };
        this.quote = { };

        this.isLoading = true;
        apexGetQuote({ opportunityId: this.recordId, quoteId: quoteId })
            .then(result => {
                console.log('result', result);
                this.quote = this.prepare(result);
                let self = this;
                this.getEntitlementInformation(() => {
                    this.populateEntitlements(this.quote.data[0]);
                    this.quoteResults = { ...this.quote, value: 'Updated data' };
                    this.isLoading = false;
                    this.importDisabled = false;
                });
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

    prepare(theQuote) {
        let result = {
            data: [ theQuote ],
            nextId: null,
            missingAccountId: false,
            error: ''
        };

        theQuote.length = theQuote.upcomingBills.lines.length;
        // convert unix time milliseconds since epoch to Date object
        theQuote.createdDate = new Date(theQuote.createdAt).toLocaleDateString(
            'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
        theQuote.expireDate = new Date(theQuote.expiresAt).toLocaleDateString(
            'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
        theQuote.statusClass = theQuote.status.includes('ACCEPTED') ? 'slds-text-color_success' : theQuote.status.includes('CANCELLED') ? 'slds-text-color_error' : '';
        theQuote._children = [];
        theQuote.id2 = `${theQuote.id}-2`;
        theQuote.lineItems.forEach(item => {
            this.lineItems[item.lineItemId] = item.entitlementId;
            this.entitlementIds[item.entitlementId] = { id: item.entitlementId };
        });
        this.quoteLineIds = {};
        theQuote.upcomingBills.lines.forEach(item => {
            theQuote._children.push({
                id: item.id,
                description: item.description,
                quantity: item.quantity,
                subTotal: item.subTotal / 100.0,
                total: item.total / 100.0,
                isoCurrency: item.isoCurrency,
                quoteLineId: item.quoteLineId
            });
        });

        if (result.missingAccountId && (result.error === undefined || result.error === null || result.error === '')) {
            result.error = this.errorMessage;
        }
        return result;
    }

    getEntitlementInformation(callback) {
        console.log('getEntitlementInformation');
        this.isLoading = true;
        let calls = 0;
        const totalCalls = Object.keys(this.entitlementIds).length * 2; // Each entitlement has 2 async calls

        Object.keys(this.entitlementIds).forEach(id => {
            let item = this.entitlementIds[id];

            apexGetEntitlementDisplayInfo({ opportunityId: this.recordId, entitlementId: item.id })
                .then(result => {
                    console.log('result', result);
                    if (result.missingAccountId === false) {
                        item['name'] = result.provisionedResource.name;
                        item['ari'] = result.provisionedResource.ari;
                        console.log('item', item);
                    }
                    calls++;
                    if (calls === totalCalls) {
                        this.isLoading = false;
                        if (callback) {
                            callback();
                        }
                    }
                })
                .catch(error => {
                    console.error('error', error);
                    this.isLoading = false;
                });
            apexGetEntitlementDetails({ opportunityId: this.recordId, entitlementId: item.id })
                .then(result => {
                    console.log('result', result);
                    if (result.missingAccountId === false) {
                        item['slug'] = result.slug;
                        console.log('item', item);
                    }
                    calls++;
                    if (calls === totalCalls) {
                        this.isLoading = false;
                        if (callback) {
                            callback();
                        }
                    }
                })
                .catch(error => {
                    console.error('error', error);
                    this.isLoading = false;
                });
        });
    }

    populateEntitlements(theQuote) {
        theQuote._children.forEach(item => {
            let lineId = this.lineItems[item.quoteLineId];
            item['entName'] = this.entitlementIds[lineId].name;
            item['entAri'] = this.entitlementIds[lineId].ari;
            item['entSlug'] = this.entitlementIds[lineId].slug;
            console.log('POPULATED item', JSON.stringify(item));
        });
        theQuote.upcomingBills.lines.forEach(item => {
            let lineId = this.lineItems[item.quoteLineId];
            item['entName'] = this.entitlementIds[lineId].name;
            item['entAri'] = this.entitlementIds[lineId].ari;
            item['entSlug'] = this.entitlementIds[lineId].slug;
            console.log('POPULATED item', JSON.stringify(item));
        });
    }

    handleImportQuote() {
        console.log('handleImportQuote() ', this.quote.data[0]);
        this.importQuote(this.quote.data[0], false);
    }

    handleImportQuoteProducts() {
        console.log('handleImportQuote() ', this.quote.data[0]);
        this.importQuote(this.quote.data[0], true);
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
                this.importQuote(this.selectedItem, false);
            }
        }
    }

    importQuote(quote, createProducts) {
        console.log('importQuote', quote);
        console.log('quote JSON', JSON.stringify(quote, null, 2));
        this.isLoading = true;
        apexImportQuote({
            jsonText: JSON.stringify(quote),
            oppId: this.recordId,
            createProducts: createProducts
        })
            .then(result => {
                console.log('result', result, JSON.stringify(result, null, 3));
                this.isLoading = false;
                this.conversionResult = result;
            })
            .catch(error => {
                this.isLoading = false;
                this.conversionResult = {
                    productLog: [],
                    pbeLog: [],
                    errorLog: [
                        JSON.stringify(error.body)
                    ]
                };
                this.quoteResults = {
                    error: JSON.stringify(error),
                    data: this.quoteResults.data,
                    nextId: null,
                    missingAccountId: true
                };
                if (error.status && error.status === 500) {
                    this.quoteResults.error = error.body.exceptionType + ': ' + error.body.message;
                }
            });
    }

    getQuotes() {
        console.log('getQuotes', this.recordId);
        this.isLoading = true;
        apexGetQuotes({ opportunityId: this.recordId })
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
                    this.quoteResults.error = error.body.exceptionType + ': ' + error.body.message + ' ==> ' + error.body.stackTrace;
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
            quote.id2 = `${quote.id}-2`;
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