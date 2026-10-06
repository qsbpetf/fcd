import LightningModal from 'lightning/modal';
import { api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import check from '@salesforce/apex/OpportunityReadinessController.check';
import closingStages from '@salesforce/apex/OpportunityReadinessController.closingStages';
import saveAndAdvance from '@salesforce/apex/OpportunityReadinessController.saveAndAdvance';

const STEP_PROMPT = 'prompt';
const STEP_FORM = 'form';

export default class OpportunityReadinessModal extends LightningModal {
    @api recordId;
    @api targetStage;
    /** Stage the record is on right now. */
    @api currentStage;
    /** When true the user picks the stage inside the modal. */
    @api allowStageChoice = false;
    /**
     * When false the window only saves the fields and leaves the stage alone.
     * The readiness panel opens it this way: the rep moves the stage on the
     * Path, the window just gets the fields filled in first.
     */
    @api advanceOnSave = false;

    @track fieldsToFill = [];
    stageOptions = [];
    guidance;
    errorMessage;
    isReady = false;
    loading = true;
    saving = false;
    step = STEP_PROMPT;

    async connectedCallback() {
        if (this.allowStageChoice) {
            try {
                this.stageOptions = await closingStages();
                if (!this.targetStage && this.stageOptions.length) {
                    this.targetStage = this.stageOptions[0].value;
                }
            } catch (e) {
                this.stageOptions = [];
            }
        }
        await this.runCheck();
    }

    async runCheck() {
        this.loading = true;
        this.errorMessage = undefined;
        try {
            const result = await check({
                recordId: this.recordId,
                targetStage: this.targetStage
            });
            this.fieldsToFill = result.fieldsToFill || [];
            // Warning-severity rules report isReady true with fields still
            // missing, so drive the UI off the gap list instead.
            this.isReady = this.fieldsToFill.length === 0;
            this.guidance = (result.blocking && result.blocking.length)
                ? result.blocking[0].guidance
                : undefined;
            this.step = STEP_PROMPT;
        } catch (e) {
            this.errorMessage = this.readError(e);
        } finally {
            this.loading = false;
        }
    }

    // ---------------------------------------------------------------- getters

    /** True when saving should write the fields and leave the stage as it is. */
    get isFixInPlace() {
        if (!this.advanceOnSave) {
            return true;
        }
        return !!this.currentStage && this.currentStage === this.targetStage;
    }

    get headerLabel() {
        if (this.isFixInPlace) {
            return 'Missing fields';
        }
        return this.targetStage ? `Move to ${this.targetStage}` : 'Readiness check';
    }

    get promptText() {
        if (this.isFixInPlace) {
            return `${this.missingCount} required field(s) are still empty. They are needed for ${this.targetStage}.`;
        }
        return `${this.missingCount} required field(s) are still empty. Fill them in and the stage change goes through; leave them and the opportunity stays at its current stage.`;
    }

    get declineLabel() {
        return this.isFixInPlace ? 'Later' : 'Not now';
    }

    get readyText() {
        return this.isFixInPlace
            ? `Nothing missing for ${this.targetStage}.`
            : `Nothing missing. This opportunity can move to ${this.targetStage}.`;
    }

    get showStagePicker() {
        return this.allowStageChoice && !this.loading && this.stageOptions.length > 1;
    }

    get showPrompt() {
        return !this.loading && !this.isReady && this.step === STEP_PROMPT;
    }

    get showForm() {
        return !this.loading && !this.isReady && this.step === STEP_FORM;
    }

    get missingCount() {
        return this.fieldsToFill.length;
    }

    get saveLabel() {
        if (this.saving) {
            return 'Saving';
        }
        return this.isFixInPlace ? 'Save' : `Save and move to ${this.targetStage}`;
    }

    // ---------------------------------------------------------------- handlers

    handleStageChange(event) {
        this.targetStage = event.detail.value;
        this.runCheck();
    }

    handleAccept() {
        this.step = STEP_FORM;
    }

    handleBack() {
        this.step = STEP_PROMPT;
    }

    handleDecline() {
        // Stage is untouched: the record is never saved on this path.
        this.close({ status: 'declined' });
    }

    handleFormError(event) {
        this.errorMessage = event.detail.message || 'The record could not be saved.';
    }

    handleFormSuccess() {
        // Not used: the save goes through Apex so fields and stage land together.
    }

    async handleSave() {
        const inputs = [...this.template.querySelectorAll('lightning-input-field')];
        const values = {};
        let hasEmpty = false;
        inputs.forEach((input) => {
            const value = input.value;
            if (value === null || value === undefined || value === '') {
                hasEmpty = true;
            }
            values[input.dataset.field] = value;
        });
        if (hasEmpty) {
            this.errorMessage = 'Fill in every field before saving.';
            return;
        }

        this.saving = true;
        this.errorMessage = undefined;
        try {
            await saveAndAdvance({
                recordId: this.recordId,
                fieldValues: values,
                targetStage: this.isFixInPlace ? null : this.targetStage
            });
            this.dispatchEvent(new ShowToastEvent({
                title: this.isFixInPlace ? 'Fields saved' : 'Stage updated',
                message: this.isFixInPlace
                    ? `Ready for ${this.targetStage}.`
                    : `Opportunity moved to ${this.targetStage}.`,
                variant: 'success'
            }));
            this.close({ status: 'saved' });
        } catch (e) {
            this.errorMessage = this.readError(e);
        } finally {
            this.saving = false;
        }
    }

    async handleAdvanceOnly() {
        if (this.isFixInPlace) {
            this.close({ status: 'closed' });
            return;
        }
        this.saving = true;
        try {
            await saveAndAdvance({
                recordId: this.recordId,
                fieldValues: {},
                targetStage: this.targetStage
            });
            this.close({ status: 'saved' });
        } catch (e) {
            this.errorMessage = this.readError(e);
            this.isReady = false;
        } finally {
            this.saving = false;
        }
    }

    readError(error) {
        if (error && error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map((e) => e.message).join(', ');
            }
            return error.body.message || 'Something went wrong.';
        }
        return error && error.message ? error.message : 'Something went wrong.';
    }
}