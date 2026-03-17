import { LightningElement, api } from 'lwc';

export default class AtlassianDealRegEditButton extends LightningElement {
    @api recordId;

    showModal = false;

    handleOpenModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
    }

    handleFormUpdated() {
        this.showModal = false;
        window.location.reload();
    }
}
