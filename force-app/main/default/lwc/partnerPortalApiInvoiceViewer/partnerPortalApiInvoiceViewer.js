/**
 * Created by peterfriberg on 2024-08-15.
 */

import { api, LightningElement, track } from 'lwc';
import apexGetInvoicesPage from '@salesforce/apex/PortalCommerceApiController.getInvoicesPage';

export default class PartnerPortalApiInvoiceViewer extends LightningElement {

    @api recordId;
    @api errorMessage;

    isLoading = true;
    isLoadingMore = false;

    invoiceGroupIndex = 0;
    nextId = null;
    hasMore = false;

    @track invoiceResults = {
        data: [],
        nextId: null,
        missingAccountId: false,
        error: ''
    };

    connectedCallback() {
        this.loadInvoicesPage(false);
    }

    loadInvoicesPage(append) {
        if (append) {
            this.isLoadingMore = true;
        } else {
            this.isLoading = true;
            this.invoiceResults = {
                data: [],
                nextId: null,
                missingAccountId: false,
                error: ''
            };
            this.invoiceGroupIndex = 0;
            this.nextId = null;
            this.hasMore = false;
        }

        apexGetInvoicesPage({
            accountId: this.recordId,
            invoiceGroupIndex: this.invoiceGroupIndex,
            nextId: this.nextId
        })
            .then(result => {
                const prepared = this.prepareInvoices(result.data || []);
                const mergedData = append
                    ? [...this.invoiceResults.data, ...prepared]
                    : prepared;

                this.invoiceGroupIndex = result.invoiceGroupIndex;
                this.nextId = result.nextId;
                this.hasMore = result.hasMore;

                if (result.missingAccountId && mergedData.length === 0) {
                    this.invoiceResults = {
                        error: result.error || this.errorMessage,
                        data: [],
                        nextId: null,
                        missingAccountId: true
                    };
                } else if (result.missingAccountId) {
                    this.invoiceResults = {
                        error: result.error,
                        data: mergedData,
                        nextId: null,
                        missingAccountId: false
                    };
                    this.hasMore = false;
                } else if (mergedData.length === 0 && !result.hasMore) {
                    this.invoiceResults = {
                        error: 'No invoices found',
                        data: [],
                        nextId: null,
                        missingAccountId: true
                    };
                } else {
                    this.invoiceResults = {
                        error: result.error || '',
                        data: mergedData,
                        nextId: result.nextId,
                        missingAccountId: false
                    };
                }

                const shouldAutoLoad = mergedData.length === 0 && this.hasMore && !result.missingAccountId;
                if (shouldAutoLoad) {
                    this.loadInvoicesPage(true);
                    return;
                }

                this.isLoading = false;
                this.isLoadingMore = false;
            })
            .catch(error => {
                console.error('error', error);
                this.isLoading = false;
                this.isLoadingMore = false;
                const hasExistingData = this.invoiceResults.data && this.invoiceResults.data.length > 0;
                this.invoiceResults = {
                    error: this.formatError(error),
                    data: this.invoiceResults.data,
                    nextId: null,
                    missingAccountId: !hasExistingData
                };
                this.hasMore = false;
            });
    }

    handleLoadMore() {
        if (this.hasMore && !this.isLoadingMore) {
            this.loadInvoicesPage(true);
        }
    }

    formatError(error) {
        if (error.status && error.status === 500) {
            return error.body.exceptionType + ': ' + error.body.message;
        }
        return JSON.stringify(error);
    }

    prepareInvoices(invoices) {
        return (invoices || []).map(invoice => {
            if (invoice.tooLargeToLoad) {
                invoice.length = 0;
                invoice.paidAtDate = '';
                invoice.items = [];
                invoice.rowClass = 'tr-error';
                invoice.paymentMethodObj = { type: 'N/A' };
                return invoice;
            }

            const items = invoice.items || [];
            invoice.length = invoice.totalItemCount || items.length;
            invoice.paidAtDate = invoice.paidAt ? new Date(invoice.paidAt).toISOString().split('T')[0] : '';
            invoice.items = items;
            invoice.rowClass = 'tr-yellow';
            invoice.truncationMessage = invoice.itemsTruncated
                ? `Showing ${items.length} of ${invoice.totalItemCount} line items. Use Preview for the full invoice.`
                : '';

            items.forEach(item => {
                item.subTotalDecimal = item.subTotal;
                item.totalDecimal = item.total;
                if (item.period) {
                    item.startAt = item.period.startAt;
                    item.startAtStr = new Date(item.period.startAt).toLocaleDateString(
                        'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
                    item.endAt = item.period.endAt;
                    item.endAtStr = new Date(item.period.endAt).toLocaleDateString(
                        'sv-SV', { year: 'numeric', month: 'numeric', day: 'numeric' });
                }
                item.discountAmount = (item.margins && item.margins.length > 0) ? item.margins[0].amount : null;
            });

            return invoice;
        });
    }

    handlePreview(event) {
        const invoiceId = event.target.getAttribute('data-id');
        const office = event.target.getAttribute('data-office');
        const visualforcePageURL = `/apex/PreviewInvoice?OFFICE=${office}&INVOICE_ID=${invoiceId}`;
        window.open(visualforcePageURL, '_blank');
    }

    get hasInvoiceData() {
        return this.invoiceResults.data && this.invoiceResults.data.length > 0;
    }

    get showLoadMore() {
        return this.hasMore && !this.invoiceResults.missingAccountId && this.hasInvoiceData;
    }
}