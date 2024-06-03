/**
 * Created by peterfriberg on 2024-05-31.
 */

import { api, track, LightningElement } from 'lwc';
import apexParseJson from '@salesforce/apex/PortalJsonController.parseJson';
import apexParseJsonAndMapProduct from '@salesforce/apex/PortalJsonController.parseJsonAndMapProduct';

export default class PartnerPortalJsonImporter extends LightningElement {

    @api recordId;

    @track jsonText;
    @track data = {
        orderItems: []
    };
    @track mapping = [];

    connectedCallback() {
        console.log('connectedCallback', this.recordId);
        debugger;
    }

    updateJson(event) {
        this.jsonText = event.target.value;
    }

    async handleImport() {
        console.log('handleImport');
        // Call apex method to parse JSON
        const result = await apexParseJson({jsonText: this.jsonText});
        console.log('result', result);
        this.data = result;
    }

    async handleMapping() {
        console.log('handleMapping');
        // Call apex method to parse JSON
        const result = await apexParseJsonAndMapProduct({jsonText: this.jsonText});
        console.log('result', result);
        this.mapping = result;
    }
}