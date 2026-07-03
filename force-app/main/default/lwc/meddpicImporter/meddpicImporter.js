import { api, track, LightningElement } from 'lwc';
import apexGetJsonFile from '@salesforce/apex/MeddpicImporter.getJsonFile';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { updateRecord } from 'lightning/uiRecordApi';

export default class MeddpicImporter extends LightningElement {

    @api recordId;

    isLoading = true;
    buttonsDisabled = true;

    @track jsonText;
    @track data = {};
    jsonTextFromFile;
    jsonTextFromTextarea = '';
    selectedSource;

    connectedCallback() {
        console.log('connectedCallback', this.recordId);
        this.isLoading = false;
        debugger;
    }

    get acceptedFormats() {
        return [ '.json' ];
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
            this.jsonTextFromFile = result;
            this.selectedSource = 'file';
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

    handleJsonInputChange(event) {
        this.jsonTextFromTextarea = event.target.value;
        if (this.jsonTextFromTextarea) {
            this.selectedSource = 'textarea';
            this.buttonsDisabled = false;
        } else if (!this.jsonTextFromFile) {
            this.buttonsDisabled = true;
            this.selectedSource = undefined;
        } else {
            this.selectedSource = 'file';
        }
    }

    handleImport() {
        let jsonString;
        if (this.selectedSource === 'textarea' && this.jsonTextFromTextarea) {
            jsonString = this.jsonTextFromTextarea;
        } else if (this.jsonTextFromFile) {
            jsonString = this.jsonTextFromFile;
        }

        if (!jsonString) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No Data',
                message: 'Please upload a file or paste MEDDPICC JSON before importing.',
                variant: 'warning'
            }));
            return;
        }

        this.isLoading = true;
        this.buttonsDisabled = true;

        try {
            this.data = JSON.parse(jsonString);
        } catch (error) {
            console.error('Failed to parse MEDDPICC JSON', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Invalid JSON',
                message: 'Please verify the MEDDPICC JSON structure and try again.',
                variant: 'error'
            }));
            this.isLoading = false;
            this.buttonsDisabled = false;
            return;
        }

        const done = () => {
            this.isLoading = false;
            this.buttonsDisabled = false;
        };

        const result = this.mapJsonToOpportunityFields(this.data);
        if (result && typeof result.then === 'function') {
            result.then(done).catch(done);
        } else {
            done();
        }
    }

    mapJsonToOpportunityFields(data) {
        const analysis = data?.MEDDPICC_Analysis;
        if (!analysis || !this.recordId) {
            console.warn('Missing MEDDPICC analysis data or recordId, skipping opportunity update');
            return Promise.resolve();
        }

        const fieldMap = [
            { jsonKey: 'M_Metrics', fieldApiName: 'Metrics__c' },
            { jsonKey: 'E_EconomicBuyer', fieldApiName: 'Economic_Buyer__c' },
            { jsonKey: 'D_DecisionCriteria', fieldApiName: 'Decision_Criteria__c' },
            { jsonKey: 'D_DecisionProcess', fieldApiName: 'Decision_Process__c' },
            { jsonKey: 'P_PaperProcess', fieldApiName: 'Paper_Process__c' },
            { jsonKey: 'I_ImplicatePain', fieldApiName: 'Identify_Pain__c' },
            { jsonKey: 'C_Champion', fieldApiName: 'Champion__c' },
            { jsonKey: 'C_Competition', fieldApiName: 'Competition__c' }
        ];

        const fields = { Id: this.recordId };
        let hasUpdates = false;

        fieldMap.forEach(mapping => {
            const section = analysis[mapping.jsonKey];
            const formattedValue = this.formatMeddpicSection(section);
            if (formattedValue) {
                fields[mapping.fieldApiName] = formattedValue;
                hasUpdates = true;
            }
        });

        if (!hasUpdates) {
            console.warn('No MEDDPICC sections contained data to update');
            return Promise.resolve();
        }

        return updateRecord({ fields })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Opportunity Updated',
                    message: 'MEDDPICC fields have been synced with the uploaded JSON.',
                    variant: 'success'
                }));
            })
            .catch(error => {
                console.error('Failed to update opportunity with MEDDPICC data', error);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error Updating Opportunity',
                    message: error?.body?.message || 'Unknown error while updating MEDDPICC fields.',
                    variant: 'error'
                }));
            });
    }

    formatMeddpicSection(section) {
        if (!section) {
            return null;
        }

        const parts = [];

        if (section.confidence) {
            parts.push(`Confidence: ${section.confidence}`);
        }

        if (section.summary) {
            parts.push(`Summary: ${section.summary}`);
        }

        if (section.gaps && Array.isArray(section.gaps) && section.gaps.length > 0) {
            const gapsText = section.gaps.map(gap => `- ${gap}`).join('\n');
            parts.push(`Gaps:\n${gapsText}`);
        }

        return parts.join('\n\n');
    }
}