/**
 * Created by peterfriberg on 2024-05-31.
 */

import { api, LightningElement } from 'lwc';

export default class PartnerPortalJsonImporter extends LightningElement {

    @api recordId;

    connectedCallback() {
        console.log('connectedCallback');
    }
}