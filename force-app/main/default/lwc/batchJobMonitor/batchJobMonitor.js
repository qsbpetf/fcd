/**
 * Created by peterfriberg on 2025-03-06.
 */

import { LightningElement, track } from 'lwc';
import getApexJobs from '@salesforce/apex/BatchJobController.getApexJobs';
import apexStartCalculationBatchJob from '@salesforce/apex/BatchJobController.startInvoiceImportBatchJob';

export default class BatchJobMonitor extends LightningElement {
    @track jobs;

    calcButtonDisabled = false;
    startButtonDisabled = false;
    stopButtonDisabled = true;
    calcJobId = null;
    intervalId;
    strength = "0";
    daysBack = 5;

    columns = [
        { label: "Apex Class Name", fieldName: "ApexClassName" },
        { label: "Job Type", fieldName: "JobType" },
        { label: "Status", fieldName: "Status" },
        {
            label: "Created Date",
            fieldName: "CreatedDate",
            type: "date",
            typeAttributes: {
                year: "numeric",
                month: "2-digit",
                day: "2-digit",
                hour: "2-digit",
                minute: "2-digit",
                hour12: false
            }
        },
        {
            label: "Completed Date",
            fieldName: "CompletedDate",
            type: "date",
            typeAttributes: {
                year: "numeric",
                month: "2-digit",
                day: "2-digit",
                hour: "2-digit",
                minute: "2-digit",
                hour12: false
            }
        },
        { label: "Job Items Processed", fieldName: "JobItemsProcessed", type: "number" },
        { label: "Total Job Items", fieldName: "TotalJobItems", type: "number" },
        { label: "Number of Errors", fieldName: "NumberOfErrors", type: "number" }
    ];

    handleInputChange(event) {
        this.daysBack = event.target.value;
        console.log('Input value changed to:', this.daysBack);
        // You can add additional logic here to handle the input value change
    }

    startMonitoring() {
        this.startButtonDisabled = true;
        this.stopButtonDisabled = false;
        this.strength = 1;
        this.fetchJobs();
        if (this.intervalId !== undefined) {
            clearInterval(this.intervalId);
        }
        this.intervalId = setInterval(() => {
            this.intervalFunction();
        }, 750);
    }

    stopMonitoring() {
        clearInterval(this.intervalId);
        this.startButtonDisabled = false;
        this.stopButtonDisabled = true;
        this.strength = "0";
    }

    fetchJobs() {
        getApexJobs()
            .then(result => {
                this.jobs = result;
                this.jobs.forEach(job => {
                    if (job.JobId === this.calcJobId && job.Status === 'Completed') {
                        console.log('Calculation job '  + this.calcJobId + ' completed');
                        this.calcButtonDisabled = false;
                        this.calcJobId = null;
                        this.stopMonitoring();
                    }
                })
            })
            .catch(error => {
                console.error('Error fetching jobs:', error);
            });
    }

    startCalculation() {
        debugger;
        this.calcButtonDisabled = true;
        this.startButtonDisabled = true;
        this.stopButtonDisabled = false;
        this.startCalculationBatchJob();
        this.fetchJobs();
        if (this.intervalId !== undefined) {
            clearInterval(this.intervalId);
        }
        this.intervalId = setInterval(() => {
            this.intervalFunction();
        }, 750);
    }

    startCalculationBatchJob() {
        console.log('Starting batchjob with daysBack: ' + this.daysBack);

        // Call the Apex method to start the batch job
        apexStartCalculationBatchJob({ daysBack: this.daysBack })
            .then(result => {
                console.log('Batch job started:', result);
                this.calcJobId = result;
            })
            .catch(error => {
                console.error('Error starting batch job:', error);
            });
    }

    intervalFunction() {
        this.fetchJobs();
        this.strength = (this.strength === "3") ? "0" : (parseInt(this.strength) + 1).toString();
    }
}