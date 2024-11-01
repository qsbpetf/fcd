/**
 * Created by peterfriberg on 2024-10-14.
 */

import { api, track, LightningElement } from 'lwc';
import apexGetInvoice from '@salesforce/apex/PortalCommerceApiController.getInvoice';
import apexGetOrder from '@salesforce/apex/PortalCommerceApiController.getOrder';
import apexImportInvoice from '@salesforce/apex/PpcInvoiceConverter.convertInvoice';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class PartnerPortalApiInvoiceImporter extends LightningElement {

    @api recordId;
    @api errorMessage;

    @track invoiceResults = {
        data: [],
        nextId: null,
        missingAccountId: false,
        error: ''
    };

    @track invoice = { };

    @track conversionResult = {
        errorLog: [],
        pbeLog: [],
        productLog: [],
        successLog: []
    };

    @track selectedItem = { id: '' }; // Used to store the clicked row data handleRowClick(event) {
    @track content;

    @track invoiceUrl;  // Typical URL =

    isLoading = false;
    importDisabled = true;
    mergeLineItems = true;

    connectedCallback() {
        console.log('connectedCallback', this.recordId);
        debugger;
    }

    handleMergeLineItemsChange(event) {
        this.mergeLineItems = event.target.checked;
    }

    handleInvoiceUrlChange(event) {
        this.invoiceUrl = event.target.value;
    }

    handleFetchInvoice() {
        console.log('getInvoice for opp', this.recordId);
        console.log('Parsing invoiceUrl', this.invoiceUrl);

        if (this.invoiceUrl === undefined || this.invoiceUrl === null || this.invoiceUrl === '') {
            return;
        }

        let parts = this.invoiceUrl.split('/');
        let invoiceId = parts[parts.length - 1];
        console.log('invoiceId', invoiceId);

        this.invoiceResults = {
            data: [],
            nextId: null,
            missingAccountId: false,
            error: ''
        };
        this.invoice = { };

        this.isLoading = true;
        this.conversionResult = {
            errorLog: [],
            pbeLog: [],
            productLog: [],
            successLog: []
        };
        apexGetInvoice({ opportunityId: this.recordId, invoiceId: invoiceId })
            .then(result => {
                console.log('result', result);
                if (result.missingAccountId) {
                    this.invoiceResults = {
                        error: result.error,
                        data: [],
                        nextId: null,
                        missingAccountId: true
                    };
                    this.isLoading = false;
                    return;
                }
                this.invoice = this.prepare(result);
                this.invoiceResults = { ...this.invoice, value: 'Updated data' };
                this.isLoading = false;
                this.importDisabled = false;
                this.invoiceId = this.invoice.data[0].id;

                // Extract all unique order numbers
                let orderIds = [...new Set(this.invoice.data[0].items.map(item => item.orderId))];
                console.log('orderIds', orderIds);

                // Fetch all orders
                let orderPromises = orderIds.map(orderId => apexGetOrder({ opportunityId: this.recordId, orderId: orderId }));

                Promise.all(orderPromises)
                    .then(orders => {
                        let orderItemsMap = {};
                        orders.forEach(order => {
                            order.items.forEach(item => {
                                orderItemsMap[item.orderItemId] = {
                                    salesType: item.processingInfo.saleTransitionType
                                };
                            });
                        });

                        console.log('orderItemsMap', orderItemsMap);

                        this.invoice.data[0].items.forEach(item => {
                            item["salesType"] = orderItemsMap[item.orderItemId]?.salesType;
                        });

                        console.log('invoice', this.invoice);

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

                        if (error.missingAccountId) {
                            this.invoiceResults = {
                                error: result.error,
                                data: [],
                                nextId: null,
                                missingAccountId: true
                            };
                            this.isLoading = false;
                            return;
                        }

                        if (error.status && error.status === 500) {
                            this.invoiceResults.error = error.body.exceptionType + ': ' + error.body.message;
                        }
                        this.isLoading = false;
                    });
            })
            .catch(error => {
                console.error('error', error);
                this.invoiceResults = {
                    error: JSON.stringify(error),
                    data: [],
                    nextId: null,
                    missingAccountId: true
                };
                if (error.status && error.status === 500) {
                    this.invoiceResults.error = error.body.exceptionType + ': ' + error.body.message;
                }
                this.isLoading = false;
            });
    }

    prepare(theInvoice) {
        let result = {
            data: [ theInvoice ],
            nextId: null,
            missingAccountId: false,
            error: ''
        };

        theInvoice.length = theInvoice.items.length;
        // convert unix time milliseconds since epoch to Date object
        theInvoice.createdDateStr = new Date(theInvoice.createdAt).toLocaleDateString(
            'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
        theInvoice.dueAtStr = new Date(theInvoice.dueAt).toLocaleDateString(
            'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
        theInvoice.paidAtStr = new Date(theInvoice.paidAt).toLocaleDateString(
            'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
        theInvoice.statusClass = theInvoice.status.includes('PAID') ? 'slds-text-color_success' : theInvoice.status.includes('UNPAID') ? 'slds-text-color_error' : '';
        theInvoice._children = [];
        theInvoice.id2 = `${theInvoice.id}-2`;
        theInvoice.items.forEach(item => {
            theInvoice._children.push({
                id: item.id,
                description: item.description,
                quantity: item.quantity,
                subTotal: item.subTotal,
                total: item.total,
                startAt: new Date(item.period.startAt).toLocaleDateString(
                    'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' }),
                endAt: new Date(item.period.endAt).toLocaleDateString(
                    'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' }),
                invoiceLineId: item.id,
                hostingType: (item.planObj) ? item.planObj.hostingType : null,
                type: (item.planObj) ? item.planObj.type : null,
            });
            item.subTotalDecimal = item.subTotal;
            item.totalDecimal = item.total;
            item.startAt = item.period.startAt;
            item.startAtStr= new Date(item.period.startAt).toLocaleDateString(
                'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
            item.endAt = item.period.endAt;
            item.endAtStr = new Date(item.period.endAt).toLocaleDateString(
                'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
            item.discountAmount = (item.margins && item.margins.length > 0)
                ? item.margins.reduce((sum, margin) => sum + margin.amount, 0)
                : 0;
            item.adjustmentAmount = (item.adjustments && item.adjustments.length > 0)
                ? item.adjustments.reduce((sum, ajdjustment) => sum + ajdjustment.amount, 0)
                : 0;
            item.amountExcludingTaxDecimal = parseFloat((item.subTotalDecimal - item.discountAmount - item.adjustmentAmount).toFixed(2));
        });
        theInvoice["total"] = theInvoice.total;
        theInvoice["subTotal"] = theInvoice.subTotal;

        if (result.missingAccountId && (result.error === undefined || result.error === null || result.error === '')) {
            result.error = this.errorMessage;
        }

        return result;
    }

    handleImportInvoice() {
        console.log('handleImportInvoice() ', this.invoice.data[0]);
        this.importInvoice(this.invoice.data[0], false);
    }

    handleImportInvoiceProducts() {
        console.log('handleImportInvoiceProducts() ', this.invoice.data[0]);
        this.importInvoice(this.invoice.data[0], true);
    }

    importInvoice(invoice, createProducts) {
        console.log('importInvoice', invoice);
        console.log('invoice JSON', JSON.stringify(invoice, null, 2));
        this.isLoading = true;
        apexImportInvoice({
            jsonText: JSON.stringify(invoice),
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
                    message: 'Invoice imported successfully' + (createProducts ? ' and products created' : ''),
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
                this.invoiceResults = {
                    error: JSON.stringify(error),
                    data: this.invoiceResults.data,
                    nextId: null,
                    missingAccountId: true
                };
                if (error.status && error.status === 500) {
                    if (error.body.message) {
                        this.invoiceResults.error = error.body.exceptionType + ': ' + error.body.message;
                    }
                    else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                        this.invoiceResults.error = error.body.pageErrors[0].statusCode + ' : ' + error.body.pageErrors[0].message;
                    }
                    else {
                        this.invoiceResults.error = JSON.stringify(error);
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
}