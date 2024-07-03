/**
 * Created by peterfriberg on 2024-05-31.
 */

import { api, track, LightningElement } from 'lwc';
import apexConvertQuote from '@salesforce/apex/PortalQuoteConverter.convertQuote';
import apexGetJsonFile from '@salesforce/apex/PortalQuoteConverter.getJsonFile';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class PartnerPortalJsonImporter extends LightningElement {

    @api recordId;

    isLoading = true;
    buttonsDisabled = true;

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

    get isErrorLogNotEmpty() {
        return this.conversionResult && this.conversionResult.errorLog && this.conversionResult.errorLog.length > 0;
    }

    get isSuccessLogNotEmpty() {
        return this.conversionResult && this.conversionResult.successLog && this.conversionResult.successLog.length > 0;
    }

    handleUploadFinished(event) {
        this.buttonsDisabled = true;
        // Get the list of uploaded files
        const uploadedFiles = event.detail.files;
        console.log('uploadedFiles', uploadedFiles);
        // Get the file
        apexGetJsonFile({
            contentBodyId: uploadedFiles[0].contentBodyId,
            contentVersionId: uploadedFiles[0].contentVersionId,
            documentId: uploadedFiles[0].documentId,
            oppId: this.recordId
        }).then(result => {
            console.log('result', result);
            this.jsonText = result;
            this.buttonsDisabled = false;
            // Show success message
            const toastEvent = new ShowToastEvent({
                title: 'Success',
                message: uploadedFiles.length + ' Files uploaded successfully: ' + uploadedFiles[0].name,
                variant: 'success',
            });
            this.dispatchEvent(toastEvent);
        }).catch(error => {
            console.log('error', error);
            // Show success message
            const toastEvent = new ShowToastEvent({
                title: 'Error',
                message: 'Error uploading files' + JSON.stringify(error),
                variant: 'error',
            });
            this.dispatchEvent(toastEvent);
        });
    }

    handleProducts() {
        this.isLoading = true;
        console.log('handleProducts');
        // Call apex method to parse JSON
        apexConvertQuote({
            jsonText: this.jsonText,
            oppId: this.recordId,
            createProducts: false
        }).then(result => {
                console.log('result', result);
                this.conversionResult = result;
                this.isLoading = false;
        }).catch(error => {
            console.error('error', error);
            this.conversionResult = {
                productLog: [],
                pbeLog: [],
                errorLog: [
                    JSON.stringify(error.body)
                ]
            };
            this.isLoading = false;
        });
    }

    createProducts() {
        this.isLoading = true;
        console.log('createProducts');
        // Call apex method to parse JSON
        apexConvertQuote({
            jsonText: this.jsonText,
            oppId: this.recordId,
            createProducts: true
        }).then(result => {
            console.log('result', result);
            this.conversionResult = result;
            this.isLoading = false;
        }).catch(error =>  {
            console.error('error', error);
            this.conversionResult = {
                productLog: [],
                pbeLog: [],
                errorLog: [
                    JSON.stringify(error.body)
                ]
            };
            this.isLoading = false;
        });
    }
}