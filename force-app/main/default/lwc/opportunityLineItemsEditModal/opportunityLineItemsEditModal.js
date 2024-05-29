import { api } from "lwc";
import LightningModal from "lightning/modal";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";

import { formatOpportunityLineItems } from "c/formatUtils";

import updateOpportunityLineItems from "@salesforce/apex/OpportunityLineItemController.updateOpportunityLineItems";
import getOpportunityLineItemsByIds from "@salesforce/apex/OpportunityLineItemController.getOpportunityLineItemsByIds";

export default class OpportunityLineItemsEditModal extends LightningModal {
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
      oliIds: this.opportunityLineItemIds
    });
    this.opportunityLineItems =
      formatOpportunityLineItems(opportunityLineItems);
    this.isFetching = false;
  }

  async handleSubmitClick() {
    const opportunityLineItems = [...this.opportunityLineItems]?.reduce(
      (accumulator, opportunityLineItem) => {
        const opportunityLineItemId = opportunityLineItem.Id;
        accumulator[opportunityLineItemId] = {
          Id: opportunityLineItemId,
          OpportunityId: this.opportunityId,
          Name: opportunityLineItem.Name,
          PricebookEntryId: opportunityLineItem.PricebookEntryId,
          UnitPrice: opportunityLineItem.UnitPrice,
          Quantity: opportunityLineItem.Quantity,
          Discount__c: opportunityLineItem.Discount__c,
          Renewal__c: opportunityLineItem.Renewal__c,
          License_Start_date__c: opportunityLineItem.License_Start_date__c,
          License_end_date__c: opportunityLineItem.License_end_date__c,
          Additional_Info__c: opportunityLineItem.Additional_Info__c,
          SEN_Technical_Contact__c:
            opportunityLineItem.SEN_Technical_Contact__c,
          SEN__c: opportunityLineItem.SEN__c,
          Loss_Reviewed__c: opportunityLineItem.Loss_Reviewed__c,
          Unusual_discount_reviewed__c:
            opportunityLineItem.Unusual_discount_reviewed__c,
          Editable_Cost_Price_in_Dollars__c:
            opportunityLineItem.Editable_Cost_Price_in_Dollars__c,
          Editable_Unit_List_Price_in_USD__c:
            opportunityLineItem.Editable_Unit_List_Price_in_USD__c
        };
        return accumulator;
      },
      {}
    );

    this.isSubmitting = true;
    try {
      const { ids, errors } = await updateOpportunityLineItems({
        olis: opportunityLineItems
      });

      await notifyRecordUpdateAvailable(ids.map((recordId) => ({ recordId })));
      await notifyRecordUpdateAvailable([{ recordId: this.opportunityId }]);

      this.opportunityLineItemErrors = errors;
      if (!Object.keys(errors).length) {
        this.close("submit");
        this.handleSuccessToastShow();
      }
    } catch (error) {
      console.error(error);
      const message = error?.body?.message ?? "An unknown error occurred";
      this.handleErrorToastShow(message);
    }
    this.isSubmitting = false;
  }

  handleErrorToastShow(message) {
    const event = new ShowToastEvent({
      title: "An error occurred",
      message,
      variant: "error"
    });
    this.dispatchEvent(event);
  }

  handleSuccessToastShow() {
    const event = new ShowToastEvent({
      title: "Success",
      message: "Opportunity Products updated",
      variant: "success"
    });
    this.dispatchEvent(event);
  }

  handleOpportunityLineItemsChange(event) {
    const opportunityLineItems = event.detail.value;
    this.opportunityLineItems =
      formatOpportunityLineItems(opportunityLineItems);
  }

  handleCancelClick() {
    this.close("cancel");
  }
}