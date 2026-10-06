import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import STAGE_FIELD from '@salesforce/schema/Opportunity.StageName';
import check from '@salesforce/apex/OpportunityReadinessController.check';
import OpportunityReadinessModal from 'c/opportunityReadinessModal';

export default class OpportunityReadinessPanel extends LightningElement {
    @api recordId;
    /** Stage the checklist is measured against. Set in App Builder. */
    @api previewStage = 'Closed won - awaiting approval';
    /**
     * Semicolon-separated stages that pop the window open by themselves
     * when something is missing. Leave blank to never auto-open.
     */
    @api autoOpenStages = 'Closing';
    /**
     * Semicolon-separated stages the record must be coming FROM for the window
     * to open. Blank means any previous stage counts.
     */
    @api autoOpenFromStages = '';

    @track fieldsToFill = [];
    isReady = false;
    loading = true;
    requiredCount = 0;
    filledFieldCount = 0;
    errorMessage;
    currentStage;

    _autoOpenInFlight = false;
    _previousStage;

    @wire(getRecord, { recordId: '$recordId', fields: [STAGE_FIELD] })
    wiredRecord({ data, error }) {
        if (data) {
            const incoming = data.fields.StageName.value;
            if (this.currentStage && this.currentStage !== incoming) {
                this._previousStage = this.currentStage;
            }
            this.currentStage = incoming;
            this.runCheck();
        } else if (error) {
            this.errorMessage = 'The record could not be read.';
            this.loading = false;
        }
    }

    async runCheck() {
        this.loading = true;
        try {
            const result = await check({
                recordId: this.recordId,
                targetStage: this.targetStage
            });
            this.fieldsToFill = result.fieldsToFill || [];
            // A warning-severity rule leaves result.isReady true even though
            // fields are missing, so readiness here means "no gaps at all".
            this.isReady = this.fieldsToFill.length === 0;
            this.requiredCount = result.requiredFieldCount || 0;
            this.filledFieldCount = result.filledFieldCount || 0;
            this.errorMessage = undefined;
            this.maybeAutoOpen();
        } catch (e) {
            this.errorMessage = e && e.body ? e.body.message : 'The check could not be run.';
        } finally {
            this.loading = false;
        }
    }

    // ------------------------------------------------------------- auto-open

    get autoOpenStageList() {
        return this.toStageList(this.autoOpenStages);
    }

    get autoOpenFromStageList() {
        return this.toStageList(this.autoOpenFromStages);
    }

    toStageList(value) {
        return (value || '')
            .split(';')
            .map((s) => s.trim().toLowerCase())
            .filter((s) => s.length > 0);
    }

    /**
     * The window is tied to a transition, not to sitting on a stage. It fires
     * when the record moves INTO an auto-open stage FROM one of the configured
     * stages, observed live on the page. A page opened directly on the target
     * stage has no observed transition, so it stays quiet and the user can
     * still use the button.
     */
    get transitionQualifies() {
        const from = this.autoOpenFromStageList;
        if (from.length === 0) {
            return true;
        }
        if (!this._previousStage) {
            return false;
        }
        return from.includes(this._previousStage.toLowerCase());
    }

    get suppressionKey() {
        return `oppReadiness:${this.recordId}:${this.currentStage}`;
    }

    /**
     * Opens the window once per record+stage. The flag lives in sessionStorage,
     * so a refresh or a second visit in the same browser session stays quiet,
     * and a new stage re-arms it.
     */
    maybeAutoOpen() {
        if (this._autoOpenInFlight || this.isReady || !this.currentStage) {
            return;
        }
        if (!this.autoOpenStageList.includes(this.currentStage.toLowerCase())) {
            return;
        }
        if (!this.transitionQualifies) {
            return;
        }
        if (this.alreadyPrompted()) {
            return;
        }
        this.markPrompted();
        // Evaluate against the stage the rep is heading for, not the one they
        // just entered: the rules live on the target stage.
        this.openModal(this.targetStage);
    }

    alreadyPrompted() {
        try {
            return window.sessionStorage.getItem(this.suppressionKey) === '1';
        } catch (e) {
            return false;
        }
    }

    markPrompted() {
        try {
            window.sessionStorage.setItem(this.suppressionKey, '1');
        } catch (e) {
            // Storage unavailable: the window opens once per page load instead.
        }
    }

    // ------------------------------------------------------------- getters

    get targetStage() {
        return this.previewStage || this.currentStage;
    }

    /** No rule applies to this opportunity, so there is nothing to report. */
    get outOfScope() {
        return this.requiredCount === 0;
    }

    get showContent() {
        return !this.loading && !this.errorMessage && !this.outOfScope;
    }

    get showOutOfScope() {
        return !this.loading && !this.errorMessage && this.outOfScope;
    }

    get hasGaps() {
        return this.fieldsToFill.length > 0;
    }

    get warningText() {
        const count = this.fieldsToFill.length;
        const noun = count === 1 ? 'field is' : 'fields are';
        return `${count} required ${noun} still empty. Fill them in before moving to ${this.targetStage}.`;
    }

    get totalCount() {
        return this.requiredCount;
    }

    get filledCount() {
        return this.filledFieldCount;
    }

    get percentComplete() {
        const total = this.totalCount;
        return total === 0 ? 100 : Math.round((this.filledCount / total) * 100);
    }

    get progressTextClass() {
        return this.hasGaps
            ? 'slds-m-top_x-small slds-m-bottom_small slds-text-color_error'
            : 'slds-m-top_x-small slds-m-bottom_small';
    }

    get progressVariant() {
        return this.isReady ? 'circular' : 'base';
    }

    // ------------------------------------------------------------- actions

    handleButtonClick() {
        this.openModal(this.targetStage);
    }

    async openModal(stage) {
        this._autoOpenInFlight = true;
        try {
            const result = await OpportunityReadinessModal.open({
                size: 'small',
                recordId: this.recordId,
                targetStage: stage,
                currentStage: this.currentStage,
                allowStageChoice: false,
                advanceOnSave: false
            });
            if (result && result.status === 'saved') {
                getRecordNotifyChange([{ recordId: this.recordId }]);
            }
            await this.runCheck();
        } finally {
            this._autoOpenInFlight = false;
        }
    }
}