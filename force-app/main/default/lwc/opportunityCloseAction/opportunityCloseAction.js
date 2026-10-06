import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import OpportunityReadinessModal from 'c/opportunityReadinessModal';

/**
 * Headless LWC quick action. Opens the readiness modal, then refreshes
 * the record page so the new stage shows immediately.
 */
export default class OpportunityCloseAction extends LightningElement {
    @api recordId;

    async invoke() {
        const result = await OpportunityReadinessModal.open({
            size: 'small',
            recordId: this.recordId,
            allowStageChoice: true,
            advanceOnSave: true
        });
        if (result && result.status === 'saved') {
            getRecordNotifyChange([{ recordId: this.recordId }]);
        }
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}