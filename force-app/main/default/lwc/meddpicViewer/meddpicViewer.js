import { LightningElement, api } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { wire } from 'lwc';

import METRICS_FIELD from '@salesforce/schema/Opportunity.Metrics__c';
import ECONOMIC_FIELD from '@salesforce/schema/Opportunity.Economic_Buyer__c';
import DECISION_CRITERIA_FIELD from '@salesforce/schema/Opportunity.Decision_Criteria__c';
import DECISION_PROCESS_FIELD from '@salesforce/schema/Opportunity.Decision_Process__c';
import PAPER_PROCESS_FIELD from '@salesforce/schema/Opportunity.Paper_Process__c';
import IDENTIFY_PAIN_FIELD from '@salesforce/schema/Opportunity.Identify_Pain__c';
import CHAMPION_FIELD from '@salesforce/schema/Opportunity.Champion__c';
import COMPETITION_FIELD from '@salesforce/schema/Opportunity.Competition__c';

const FIELD_CONFIG = [
    { label: 'Metrics', fieldApiName: METRICS_FIELD },
    { label: 'Economic Buyer', fieldApiName: ECONOMIC_FIELD },
    { label: 'Decision Criteria', fieldApiName: DECISION_CRITERIA_FIELD },
    { label: 'Decision Process', fieldApiName: DECISION_PROCESS_FIELD },
    { label: 'Paper Process', fieldApiName: PAPER_PROCESS_FIELD },
    { label: 'Identify Pain', fieldApiName: IDENTIFY_PAIN_FIELD },
    { label: 'Champion', fieldApiName: CHAMPION_FIELD },
    { label: 'Competition', fieldApiName: COMPETITION_FIELD }
];

const FIELD_API_NAMES = FIELD_CONFIG.map(config => config.fieldApiName);

export default class MeddpicViewer extends LightningElement {
    @api recordId;

    sections = [];
    error;
    isLoading = true;

    @wire(getRecord, { recordId: '$recordId', fields: FIELD_API_NAMES })
    wiredOpportunity({ error, data }) {
        this.isLoading = false;
        if (error) {
            // Surface first message for display
            this.error = Array.isArray(error.body) ? error.body[0].message : error.body?.message || error.message;
            this.sections = [];
        } else if (data) {
            this.error = undefined;
            this.sections = this.buildSections(data);
        }
    }

    buildSections(recordData) {
        return FIELD_CONFIG.map(config => {
            const rawValue = getFieldValue(recordData, config.fieldApiName);
            const parsed = this.parseFieldValue(rawValue);
            return {
                key: config.label.toLowerCase().replace(/\s+/g, '-'),
                label: config.label,
                confidence: parsed.confidence,
                confidenceClass: this.getConfidenceClass(parsed.confidence),
                summary: parsed.summary,
                gaps: parsed.gaps,
                hasContent: parsed.hasContent
            };
        });
    }

    parseFieldValue(value) {
        const result = {
            confidence: 'Not Provided',
            summary: '',
            gaps: [],
            hasContent: false
        };

        if (!value || !value.trim()) {
            return result;
        }

        result.hasContent = true;

        const confidenceMatch = value.match(/Confidence:\s*([^\n]+)/i);
        if (confidenceMatch) {
            result.confidence = confidenceMatch[1].trim();
        }

        const summaryMatch = value.match(/Summary:\s*([\s\S]*?)(?:\n\s*\n|$)/i);
        if (summaryMatch) {
            result.summary = summaryMatch[1].trim();
        }

        const gapsMatch = value.match(/Gaps:\s*([\s\S]*)/i);
        if (gapsMatch) {
            const gapLines = gapsMatch[1]
                .split('\n')
                .map(line => line.replace(/^-/, '').trim())
                .filter(line => line.length > 0);
            result.gaps = gapLines;
        }

        return result;
    }

    getConfidenceClass(confidence) {
        switch ((confidence || '').toLowerCase()) {
            case 'green':
                return 'meddpic-badge meddpic-badge--green';
            case 'yellow':
                return 'meddpic-badge meddpic-badge--yellow';
            case 'red':
                return 'meddpic-badge meddpic-badge--red';
            default:
                return 'meddpic-badge meddpic-badge--neutral';
        }
    }

    get hasSections() {
        return this.sections && this.sections.length > 0;
    }
}