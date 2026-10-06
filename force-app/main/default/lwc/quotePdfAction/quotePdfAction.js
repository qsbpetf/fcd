import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getResolution from '@salesforce/apex/QuotePdfService.getResolution';
import regenerateTerms from '@salesforce/apex/QuotePdfService.regenerateTerms';
import savePdf from '@salesforce/apex/QuotePdfService.savePdf';

export default class QuotePdfAction extends LightningElement {
    @api recordId;
    resolution;
    errorMessage;
    wiredResult;
    languageOverride = '';
    busy = false;

    languageOptions = [
        { label: 'As set on the quote', value: '' },
        { label: 'English', value: 'English' },
        { label: 'German', value: 'German' }
    ];

    @wire(getResolution, { quoteId: '$recordId', languageOverride: '$languageOverride' })
    wiredResolution(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.resolution = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.resolution = undefined;
            this.errorMessage = this.reduceError(error);
        }
    }

    get isLoading() {
        return !this.resolution && !this.errorMessage;
    }

    get offerBadgeClass() {
        return this.resolution?.offerType === 'Binding' ? 'offer-badge offer-badge_binding' : 'offer-badge';
    }

    get productRows() {
        return (this.resolution?.products ?? []).map((p, i) => ({
            key: `${i}-${p.productName}`,
            productName: p.productName,
            groupLabel: p.groupLabel,
            source: p.source,
            rowClass: p.groupKey ? 'product-row' : 'product-row product-row_unmapped'
        }));
    }

    get hasProducts() {
        return this.productRows.length > 0;
    }

    get sectionRows() {
        return this.moduleRows(['Terms']);
    }

    get bulletRows() {
        return this.moduleRows(['Additional']);
    }

    get extraRows() {
        return this.moduleRows(['Notice', 'Promo']);
    }

    get hasExtras() {
        return this.extraRows.length > 0;
    }

    get hasBullets() {
        return this.bulletRows.length > 0;
    }

    moduleRows(placements) {
        return (this.resolution?.modules ?? [])
            .filter((m) => placements.includes(m.placement))
            .map((m) => ({
                key: m.code,
                name: m.title || this.humanize(m.code),
                because: m.appliesBecause,
                fallback: m.isFallback
            }));
    }

    get hasWarnings() {
        return (this.resolution?.warnings ?? []).length > 0;
    }

    get actionsDisabled() {
        return this.busy || !this.resolution;
    }

    handleLanguageChange(event) {
        this.languageOverride = event.detail.value;
    }

    handlePreview() {
        let url = `/apex/QuoteModularPdf?id=${this.recordId}`;
        if (this.languageOverride) url += `&lang=${encodeURIComponent(this.languageOverride)}`;
        window.open(url, '_blank');
    }

    async handleRegenerate() {
        await this.run(async () => {
            await regenerateTerms({ quoteId: this.recordId });
            await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            await refreshApex(this.wiredResult);
            this.toast('Terms updated on quote', 'Terms and Conditions now match the products on this quote.', 'success');
        }, 'Terms were not updated');
    }

    async handleSave() {
        await this.run(async () => {
            await savePdf({ quoteId: this.recordId, languageOverride: this.languageOverride });
            this.toast('PDF saved to quote', 'Find it in the Quote PDFs related list.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        }, 'PDF was not saved');
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async run(fn, errorTitle) {
        this.busy = true;
        try {
            await fn();
        } catch (error) {
            this.toast(errorTitle, this.reduceError(error), 'error');
        } finally {
            this.busy = false;
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    humanize(code) {
        return (code || '').toLowerCase().replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase());
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) return error.body.map((e) => e.message).join(', ');
        return error?.body?.message || error?.message || 'Unknown error';
    }
}