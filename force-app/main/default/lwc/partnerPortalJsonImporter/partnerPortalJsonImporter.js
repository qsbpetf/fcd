/**
 * Created by peterfriberg on 2024-05-31.
 */

import { api, track, LightningElement } from 'lwc';
import apexConvertQuote from '@salesforce/apex/PortalQuoteConverter.convertQuote';
import apexUpdateOpportunity from '@salesforce/apex/PortalQuoteConverter.updateOpportunity';
import apexGetJsonFile from '@salesforce/apex/PortalQuoteConverter.getJsonFile';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class PartnerPortalJsonImporter extends LightningElement {

    @api recordId;

    isLoading = true;
    buttonsDisabled = true;
    maxItemsToProcess = 50;
    productCount = 0;
    processStatus = '';

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

    handleMaxItemsChange(event) {
        this.maxItemsToProcess = event.target.value;
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
            this.data = JSON.parse(this.jsonText);
            this.productCount = this.data.orderItems.length;
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
        debugger;
        this.isLoading = true;
        this.processBatch(false);
    }

    createProducts() {
        this.isLoading = true;
        this.processBatch(true);
    }

    processBatch(createProducts, startIndex = 0) {
        const itemCount = Math.min(this.maxItemsToProcess, this.productCount - startIndex);
        console.log('Processing batch. Startindex:', startIndex, 'ItemCount:', itemCount);
        this.processStatus = startIndex + ' .. ' + (startIndex + itemCount);
        apexConvertQuote({
            jsonText: this.jsonText,
            oppId: this.recordId,
            createProducts: createProducts,
            startIndex: startIndex,
            itemCount: itemCount
        }).then(result => {
            this.conversionResult = result;
            this.productCount = this.conversionResult.productCount;
            this.isLoading = false;

            if (startIndex + itemCount < this.productCount) {
                setTimeout(() => {
                    this.processBatch(createProducts, startIndex + itemCount);
                }, 2000); // Delay of 2 seconds
             } else {
                 this.processStatus = 'Updating Oppty!';
                 this.updateOpportunity(createProducts);
             }
        }).catch(error => {
            this.conversionResult = {
                productLog: [],
                pbeLog: [],
                errorLog: [
                    JSON.stringify(error.body)
                ]
            };
            this.processStatus = 'Error!';
            this.isLoading = false;
        });
    }

    updateOpportunity(createProducts) {
        console.log('Update oppty');
        apexUpdateOpportunity({
            jsonText: this.jsonText,
            oppId: this.recordId,
            createProducts: createProducts
        }).then(() => {
            this.processStatus = 'Done!';
            this.isLoading = false;
        }).catch(error => {
            this.processStatus = 'Error!';
            this.conversionResult.errorLog.push(JSON.stringify(error.body));
            this.isLoading = false;
        });
        this.isLoading = false;
    }
}