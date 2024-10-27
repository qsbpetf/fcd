/**
 * Created by peterfriberg on 2024-08-13.
 */

import { api, track, LightningElement } from 'lwc';
import apexGetQuotes from '@salesforce/apex/PortalCommerceApiController.getQuotes';
import apexGetQuote from '@salesforce/apex/PortalCommerceApiController.getQuote';
import apexImportQuote from '@salesforce/apex/PpcQuoteConverter.convertQuote';
import apexGetOrderPreview from '@salesforce/apex/PortalCommerceApiController.getOrderPreview';
import apexGetEntitlementDisplayInfo from '@salesforce/apex/PortalCommerceApiController.getEntitlementDisplayInfo';
import apexGetEntitlementDetails from '@salesforce/apex/PortalCommerceApiController.getEntitlementDetails';
import apexGetEntitlementPartnerInfo from '@salesforce/apex/PortalCommerceApiController.getEntitlementPartnerInfo';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class PartnerPortalApiQuoteImporter extends LightningElement {

    @api recordId;
    @api errorMessage;

    @track quoteResults = {
        data: [],
        nextId: null,
        missingAccountId: false,
        error: ''
    };

    @track quote = { };

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
    quoteId = '';
    mergeLineItems = true;

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

    handleMergeLineItemsChange(event) {
        this.mergeLineItems = event.target.checked;
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
        this.entitlementIds = { };

        this.isLoading = true;
        this.conversionResult = {
            errorLog: [],
            pbeLog: [],
            productLog: [],
            successLog: []
        };
        apexGetQuote({ opportunityId: this.recordId, quoteId: quoteId })
            .then(result => {
                console.log('result', result);
                if (result.missingAccountId) {
                    this.quoteResults = {
                        error: result.error,
                        data: [],
                        nextId: null,
                        missingAccountId: true
                    };
                    this.isLoading = false;
                    return;
                }
                this.quote = this.prepare(result);
                let self = this;

                this.getEntitlementInformation(() => {
                    this.populateEntitlements(this.quote.data[0]);
                    this.quoteResults = { ...this.quote, value: 'Updated data' };
                    this.isLoading = false;
                    this.importDisabled = false;
                    this.quoteId = this.quote.data[0].id;
                });

                // Quote is OPEN
                if (this.quote.data[0].status === 'OPEN') {
                    apexGetOrderPreview({
                        opportunityId: this.recordId,
                        quoteId: this.quote.data[0].id,
                        quoteVersion: this.quote.data[0].version
                    })
                        .then(order => {
                            console.log('order', JSON.stringify(order));

                            if (order.missingAccountId) {
                                this.quote = {
                                    error: JSON.stringify(order),
                                    data: [],
                                    nextId: null,
                                    missingAccountId: true
                                };
                                if (order.status && order.status === 500) {
                                    this.quote.error = order.body.exceptionType + ': ' + order.body.message;
                                }
                            }

                            let orderItems = order.items.map(item => {
                                return {
                                    quoteLineItemId: item.quoteLineItemDetailsReference.quoteLineItemId,
                                    salesType: item.processingInfo.saleTransitionType
                                }
                            });

                            console.log('orderItems', (orderItems));

                            let orderItemsMap = order.items.reduce((acc, item) => {
                                acc[item.quoteLineItemDetailsReference.quoteLineItemId] = {
                                    salesType: item.processingInfo.saleTransitionType
                                };
                                return acc;
                            }, {});

                            console.log('orderItemsMap', orderItemsMap);

                            this.quote.data[0].upcomingBills.lines.forEach(item => {
                                item.salesType = orderItemsMap[item.quoteLineId].salesType;
                            });

                            console.log('this.quote.data[0]', this.quote.data[0]);

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
            theQuote.isoCurrency = item.isoCurrency;
            theQuote._children.push({
                id: item.id,
                description: item.description,
                quantity: item.quantity,
                subTotal: item.subTotal / 100.0,
                total: item.total / 100.0,
                isoCurrency: item.isoCurrency,
                quoteLineId: item.quoteLineId,
                startsAt: new Date(item.period.startsAt).toLocaleDateString(
                    'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' }),
                endsAt: new Date(item.period.endsAt).toLocaleDateString(
                    'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' })
            });
            item.subTotalDecimal = item.subTotal / 100.0;
            item.totalDecimal = item.total / 100.0;
            item.taxDecimal = item.tax / 100.0;
            item.startsAt= new Date(item.period.startsAt).toLocaleDateString(
                'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
            item.endsAt = new Date(item.period.endsAt).toLocaleDateString(
                'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
            item.discount = (item.margins && item.margins.length > 0)
                ? item.margins.reduce((sum, margin) => sum + margin.amount, 0)
                : 0;
            item.discountAmount = (item.margins && item.margins.length > 0)
                ? item.margins.reduce((sum, margin) => sum + margin.amount, 0) / 100.0
                : 0;
            item.adjustment = (item.adjustments && item.adjustments.length > 0)
                ? item.adjustments.reduce((sum, adjustment) => sum + adjustment.amount, 0)
                : 0;
            item.adjustmentAmount = (item.adjustments && item.adjustments.length > 0)
                ? item.adjustments.reduce((sum, ajdjustment) => sum + ajdjustment.amount, 0) / 100.0
                : 0;
            item.amountExcludingTax = item.subTotal - item.discount - item.adjustment;
            item.amountExcludingTaxDecimal = item.amountExcludingTax / 100.0;
            item.uniqueKey = item.id + item.description + item.quantity + item.subTotal + item.total + item.isoCurrency + item.startsAt + item.endsAt;
        });
        theQuote["total"] = theQuote.upcomingBills.total / 100.0;
        theQuote["subTotal"] = theQuote.upcomingBills.subTotal / 100.0;

        if (result.missingAccountId && (result.error === undefined || result.error === null || result.error === '')) {
            result.error = this.errorMessage;
        }
        return result;
    }

    getEntitlementInformation(callback) {
        console.log('getEntitlementInformation');
        this.isLoading = true;
        let calls = 0;
        const totalCalls = Object.keys(this.entitlementIds).length;

        Object.keys(this.entitlementIds).forEach(id => {
            let item = this.entitlementIds[id];

            apexGetEntitlementPartnerInfo({ opportunityId: this.recordId, entitlementId: item.id })
                .then(result => {
                    console.log('result', result);
                    if (result.missingAccountId === false) {
                        item['name'] = result.provisionedResource.name;
                        item['ari'] = result.provisionedResource.ari;
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
                    console.error('error', JSON.stringify(error));
                    calls++;
                    if (calls === totalCalls) {
                        this.isLoading = false;
                        if (callback) {
                            callback();
                        }
                    }
                });
        });
    }

    populateEntitlements(theQuote) {
        theQuote._children.forEach(item => {
            let lineId = this.lineItems[item.quoteLineId];
            item['entName'] = this.entitlementIds[lineId].name ? this.entitlementIds[lineId].name : null ;
            item['entAri'] = this.entitlementIds[lineId].ari ? this.entitlementIds[lineId].ari : null ;
            item['entSlug'] = this.entitlementIds[lineId].slug ? this.entitlementIds[lineId].slug : null ;
            console.log('POPULATED item', JSON.stringify(item));
        });
        theQuote.upcomingBills.lines.forEach(item => {
            let lineId = this.lineItems[item.quoteLineId];
            item['entName'] = this.entitlementIds[lineId].name ? this.entitlementIds[lineId].name : null;
            item['entAri'] = this.entitlementIds[lineId].ari ? this.entitlementIds[lineId].ari : null;
            item['entSlug'] = this.entitlementIds[lineId].slug ? this.entitlementIds[lineId].slug : null;
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
            createProducts: createProducts,
            mergeLineItems: this.mergeLineItems
        })
            .then(result => {
                console.log('result', result, JSON.stringify(result, null, 3));
                this.isLoading = false;
                this.conversionResult = this.mapResults(result);
                const toastEvent = new ShowToastEvent({
                    title: 'Success',
                    message: 'Quote imported successfully' + (createProducts ? ' and products created' : ''),
                    variant: 'success',
                });
                this.dispatchEvent(toastEvent);
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
                    if (error.body.message) {
                        this.quoteResults.error = error.body.exceptionType + ': ' + error.body.message;
                    }
                    else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                        this.quoteResults.error = error.body.pageErrors[0].statusCode + ' : ' + error.body.pageErrors[0].message;
                    }
                    else {
                        this.quoteResults.error = JSON.stringify(error);
                    }
                }
                const toastEvent = new ShowToastEvent({
                    title: 'Error',
                    message: 'Error when importing quote ' + (createProducts ? ' and creating products.' : '.') + JSON.stringify(error),
                    variant: 'error',
                });
                this.dispatchEvent(toastEvent);
            });
    }

    mapResults(result) {
        // iterate through productLog, pbeLog and errorLog and map each element into an object with a key and value where key is a unique number and value is the element
        let productLog = result.productLog.map((element, index) => {
            return { key: index, value: element };
        });
        let pbeLog = result.pbeLog.map((element, index) => {
            return { key: index, value: element };
        });
        let errorLog = result.errorLog.map((element, index) => {
            return { key: index, value: element };
        });
        let successLog = result.successLog.map((element, index) => {
            return { key: index, value: element };
        });
        return {
            productLog: productLog,
            pbeLog: pbeLog,
            errorLog: errorLog,
            successLog: successLog
        };
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
                    isoCurrency: item.isoCurrency,
                    startsAt: new Date(item.period.startsAt).toLocaleDateString(
                        'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' }),
                    endsAt: new Date(item.period.endsAt).toLocaleDateString(
                        'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' })
                });
                item.startsAt= new Date(item.period.startsAt).toLocaleDateString(
                    'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
                item.endsAt = new Date(item.period.endsAt).toLocaleDateString(
                    'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
            });
        });
        if (result.missingAccountId && (result.error === undefined || result.error === null || result.error === '')) {
            result.error = this.errorMessage;
        }
        return result;
    }

    handlePreview(event) {
        console.log('handlePreview', JSON.stringify(event));
        const invoiceId = event.target.dataset.id;
        console.log('Preview button clicked for invoice Id:', invoiceId);
        const office = this.quote.data[0].office;
        console.log('Office: ', office);

        const quoteId = event.target.getAttribute('data-id');
        console.log('qid:', quoteId);

        const visualforcePageURL = `/apex/PreviewQuote?OFFICE=${office}&QUOTE_ID=${invoiceId}`;
        window.open(visualforcePageURL, '_blank');
    }
}