import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';

import { formatOpportunityLineItems } from 'c/formatUtils';

import deleteOpportunityLineItems from '@salesforce/apex/OpportunityLineItemController.deleteOpportunityLineItems';
import getOpportunityLineItemsByIds from '@salesforce/apex/OpportunityLineItemController.getOpportunityLineItemsByIds';

export default class OpportunityLineItemsDeleteModal extends LightningModal {
    @api opportunityId;
    @api opportunityLineItemIds;

    opportunityLineItems = [];
    opportunityLineItemErrors = {};

    isSubmitting = false;
    isFetching = false;

    connectedCallback() {
        this.handleOpportunityLineItemsGet();
    }

    async handleOpportunityLineItemsGet() {
        this.isFetching = true;
        const opportunityLineItems = await getOpportunityLineItemsByIds({
            oliIds: this.opportunityLineItemIds,
        });
        this.opportunityLineItems = formatOpportunityLineItems(opportunityLineItems);
        this.isFetching = false;
    }

    async handleSubmitClick() {
        this.isSubmitting = true;
        try {
            const { ids, errors } = await deleteOpportunityLineItems({
                oliIds: this.opportunityLineItemIds,
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
            message: 'Opportunity Products deleted',
            variant: 'success',
        });
        this.dispatchEvent(event);
    }

    handleCancelClick() {
        this.close('cancel');
    }

    get computedOpportunityLineItems() {
        return this.opportunityLineItems.map((opportunityLineItem) => {
            const error = this.opportunityLineItemErrors?.[opportunityLineItem.Id];
            return {
                ...opportunityLineItem,
                error,
            };
        });
    }
}
