/**
 * Created by peterfriberg on 2024-05-31.
 */

import { api, track, LightningElement } from 'lwc';
import apexParseJson from '@salesforce/apex/PortalJsonController.parseJson';
import apexParseJsonAndMapProduct from '@salesforce/apex/PortalJsonController.parseJsonAndMapProduct';
import apexConvertQuote from '@salesforce/apex/PortalQuoteConverter.convertQuote';
import apexGetJsonFile from '@salesforce/apex/PortalQuoteConverter.getJsonFile';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class PartnerPortalJsonImporter extends LightningElement {

    @api recordId;

    isLoading = true;
    conversionFactor = 1;

    @track jsonText;
    @track data = {
        orderItems: []
    };
    @track mapping = [];
    @track conversionResult = {
        productLog: [],
        pbeLog: []
    };

    connectedCallback() {
        console.log('connectedCallback', this.recordId);
        this.isLoading = false;
        debugger;
    }

    get acceptedFormats() {
        return [ '.json' ];
    }

    async handleUploadFinished(event) {
        // Get the list of uploaded files
        const uploadedFiles = event.detail.files;
        console.log('uploadedFiles', uploadedFiles);
        // Show success message
        const toastEvent = new ShowToastEvent({
            title: 'Success',
            message: uploadedFiles.length + ' Files uploaded successfully: ' + uploadedFiles[0].name,
            variant: 'success',
        });
        this.dispatchEvent(toastEvent);
        // Get the file
        let result = await apexGetJsonFile({
            contentBodyId: uploadedFiles[0].contentBodyId,
            contentVersionId: uploadedFiles[0].contentVersionId,
            documentId: uploadedFiles[0].documentId,
            oppId: this.recordId
        });
        console.log('result', result);
        this.jsonText = result;
    }

    updateJson(event) {
        this.jsonText = event.target.value;
    }

    updateConversionFactor(event) {
        this.conversionFactor = event.target.value;
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

    async handleProducts() {
        this.isLoading = true;
        console.log('handleProducts');
        // Call apex method to parse JSON
        try {
            const result = await apexConvertQuote({
                jsonText: this.jsonText,
                oppId: this.recordId,
                createProducts: false
            });
            console.log('result', result);
            this.conversionResult = result;
            this.isLoading = false;
        }
        catch (error) {
            console.error('error', error);
            this.conversionResult = {
                productLog: [
                    JSON.stringify(error.body)
                ],
                pbeLog: []
            };
            this.isLoading = false;
        }
    }

    async createProducts() {
        this.isLoading = true;
        console.log('createProducts');
        // Call apex method to parse JSON
        try {
            const result = await apexConvertQuote({
                jsonText: this.jsonText,
                oppId: this.recordId,
                createProducts: true
            });
            console.log('result', result);
            this.conversionResult = result;
            this.isLoading = false;
        }
        catch (error) {
            console.error('error', error);
            this.conversionResult = {
                productLog: [
                    JSON.stringify(error.body)
                ],
                pbeLog: []
            };
            this.isLoading = false;
        }
    }
}