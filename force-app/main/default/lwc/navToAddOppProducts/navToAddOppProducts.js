import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import OpportunityLineItemsAddModal from "c/opportunityLineItemsAddModal";

export default class NavToAddOppProducts extends NavigationMixin(LightningElement) {

    oppId;

    openModal() {
        OpportunityLineItemsAddModal.open({
            size: 'large',
            opportunityId: this.oppId
        })
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        this.oppId = currentPageReference.state.c__oppId;
        this.openModal();
    }

    handleBackToOpportunity() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.oppId,
                objectApiName: 'Opportunity',
                actionName: 'view'
            }
        });
    }

    handleToListView() {
        console.log('handleToListView');
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.oppId,
                objectApiName: 'Opportunity',
                relationshipApiName: 'OpportunityLineItems',
                actionName: 'view'
            }
        })
    }

}