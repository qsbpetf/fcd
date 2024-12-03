import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import insertOpportunityLineItems from '@salesforce/apex/OpportunityLineItemController.insertOpportunityLineItems';

import { formatOpportunityLineItems } from 'c/formatUtils';

export default class OpportunityLineItemsAddModal extends LightningModal {
    @api opportunityId;

    opportunityLineItems = [];
    opportunityLineItemErrors = {};

    isSubmitting = false;
    phase = 1;
    phases = [
        { value: 1, label: 'Search Products' },
        { value: 2, label: 'Add Opportunity Products' },
    ];

    handleCancelClick() {
        this.close('cancel');
    }

    handleNextClick() {
        this.phase = 2;
    }

    handleBackClick() {
        this.phase = 1;
    }

    /**
     * @description Create a map of OpportunityLineItem records where the key is the OpportunityLineItem Id. Pick only required fields.
     */
    async handleSubmitClick() {
        const opportunityLineItems = [...this.opportunityLineItems]?.reduce((accumulator, opportunityLineItem) => {
            const opportunityLineItemId = opportunityLineItem?.Id;
            accumulator[opportunityLineItemId] = {
                OpportunityId: this.opportunityId,
                Name: opportunityLineItem?.Name,
                PricebookEntryId: opportunityLineItem?.PricebookEntryId,
                UnitPrice: opportunityLineItem?.UnitPrice,
                Quantity: opportunityLineItem?.Quantity,
                Discount__c: opportunityLineItem?.Discount__c,
                Renewal__c: opportunityLineItem?.Renewal__c,
                License_Start_date__c: opportunityLineItem?.License_Start_date__c,
                License_end_date__c: opportunityLineItem?.License_end_date__c,
                Additional_Info__c: opportunityLineItem?.Additional_Info__c,
                SEN_Technical_Contact__c: opportunityLineItem?.SEN_Technical_Contact__c,
                SEN__c: opportunityLineItem?.SEN__c,
                Loss_Reviewed__c: opportunityLineItem?.Loss_Reviewed__c,
                Unusual_discount_reviewed__c: opportunityLineItem?.Unusual_discount_reviewed__c,
                User_Count__c: opportunityLineItem?.User_Count__c,
                Editable_Cost_Price_in_Dollars__c: opportunityLineItem?.Editable_Cost_Price_in_Dollars__c,
                Editable_Unit_List_Price_in_USD__c: opportunityLineItem?.Editable_Unit_List_Price_in_USD__c,
            };
            return accumulator;
        }, {});

        this.isSubmitting = true;
        try {
            const { ids, errors } = await insertOpportunityLineItems({
                olis: opportunityLineItems,
            });

            await notifyRecordUpdateAvailable(ids.map((recordId) => ({ recordId })));
            await notifyRecordUpdateAvailable([{ recordId: this.opportunityId }]);

            this.opportunityLineItemErrors = errors;
            if (!Object.keys(errors).length) {
                this.close('submit');
                this.handleSuccessToastShow();
            }
        } catch (error) {
            console.error(error);
            const message = error?.body?.message ?? 'An unknown error occurred';
            this.handleErrorToastShow(message);
        }
        this.isSubmitting = false;
    }

    handleErrorToastShow(message) {
        const event = new ShowToastEvent({
            title: 'An error occurred',
            message,
            variant: 'error',
        });
        this.dispatchEvent(event);
    }

    handleSuccessToastShow() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Opportunity Products added',
            variant: 'success',
        });
        this.dispatchEvent(event);
    }

    handleOpportunityLineItemsChange(event) {
        const opportunityLineItems = event.detail.value;
        this.opportunityLineItems = formatOpportunityLineItems(opportunityLineItems);
    }

    handlePhaseChange(event) {
        const nextPhase = event.detail.value;
        this.phase = nextPhase;
    }

    get isPhase1() {
        return this.phase === 1;
    }

    get isPhase2() {
        return this.phase === 2;
    }
}
