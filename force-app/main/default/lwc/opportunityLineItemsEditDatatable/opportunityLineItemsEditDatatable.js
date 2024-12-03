import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import CurrencyIsoCode from '@salesforce/schema/Opportunity.CurrencyIsoCode';
import getTypePicklistValues from '@salesforce/apex/OpportunityLineItemController.getTypePicklistValues';

export default class OpportunityEditLineItemsDatatable extends LightningElement {
    @api opportunityId;
    @api opportunityLineItems = [];
    @api opportunityLineItemErrors = {};
    @api isFetching = false;
    @api isSubmitting = false;
    @api isDeletable = false;

    @track opportunityLineItemColumns = [];
    @track types = [];
    @track opportunity = {};

    @wire(getRecord, {
        recordId: '$opportunityId',
        fields: [CurrencyIsoCode],
    })
    getOpportunityRecord({ data, error }) {
        if (data) {
            this.opportunity = {
                CurrencyIsoCode: getFieldValue(data, CurrencyIsoCode),
            };
            this.handleOpportunityLineItemColumnsSet();
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getTypePicklistValues) getTypePicklistValuesWire({ data, error }) {
        if (data) {
            this.types = data;
            this.handleOpportunityLineItemColumnsSet();
        } else if (error) {
            console.error(error);
        }
    }

    connectedCallback() {
        this.handleOpportunityLineItemColumnsSet();
    }

    handleOpportunityLineItemsChange(opportunityLineItems) {
        const event = new CustomEvent('opportunitylineitemschange', {
            detail: {
                value: opportunityLineItems,
            },
        });
        this.dispatchEvent(event);
    }

    handlePhaseChange(phase) {
        const event = new CustomEvent('phasechange', {
            detail: {
                value: phase,
            },
        });
        this.dispatchEvent(event);
    }

    handleBackClick() {
        this.handlePhaseChange(1);
    }

    handleOpportunityLineItemsRowAction(event) {
        const opportunityLineItemId = event?.detail?.row?.Id;
        const opportunityLineItems = [...this.opportunityLineItems]?.filter(
            (opportunityLineItem) => opportunityLineItem.Id !== opportunityLineItemId,
        );
        this.handleOpportunityLineItemsChange(opportunityLineItems);
    }

    handleOpportunityLineItemsCellChange(event) {
        const nextOpportunityLineItem = this.handleDraftValueFormat(event?.detail?.draftValues?.[0]);
        const opportunityLineItems = [...this.opportunityLineItems]?.map((opportunityLineItem) => {
            if (opportunityLineItem?.Id === nextOpportunityLineItem?.Id) {
                return { ...opportunityLineItem, ...nextOpportunityLineItem };
            }
            return opportunityLineItem;
        });
        let areAllTypeFieldsPopulated = true;
        opportunityLineItems.forEach((opportunityLineItem) => {
            if (!opportunityLineItem.Renewal__c) {
                areAllTypeFieldsPopulated = false;
            }
        });
        this.opportunityLineItemColumns = [...this.opportunityLineItemColumns]?.map((c) => {
            if (c.fieldName === 'Renewal__c') {
                return { ...c, label: areAllTypeFieldsPopulated ? 'Type' : 'Type *' };
            }
            return c;
        });

        this.handleOpportunityLineItemsChange(opportunityLineItems);
    }

    handleDraftValueFormat(draftValue) {
        const contact = draftValue.SEN_Technical_Contact__c;
        if (contact?.includes('|')) {
            const [contactId, contactName] = contact.split('|');
            return {
                ...draftValue,
                SEN_Technical_Contact__c: contactId,
                SEN_Technical_Contact__r: {
                    Name: contactName,
                },
            };
        }
        return draftValue;
    }

    handleOpportunityLineItemColumnsSet() {
        this.opportunityLineItemColumns = [
            {
                label: 'Product',
                fieldName: 'PricebookEntry.Product2.Name',
                initialWidth: 300,
                type: 'text',
            },
            {
                label: 'Quantity',
                fieldName: 'Quantity',
                type: 'number',
                initialWidth: 100,
                editable: true,
            },
            {
                label: 'Unit List Price',
                fieldName: 'UnitPrice',
                type: 'currency',
                typeAttributes: {
                    currencyCode: this.opportunity?.CurrencyIsoCode,
                },
                initialWidth: 150,
                editable: true,
            },
            {
                label: 'Discount',
                fieldName: 'Discount__c',
                type: 'discount',
                typeAttributes: {
                    name: 'Discount__c',
                },
                cellAttributes: {
                    alignment: 'right',
                },
                initialWidth: 100,
                editable: true,
            },
            {
                label: 'Type *',
                fieldName: 'Renewal__c',
                type: 'picklist',
                typeAttributes: {
                    name: 'Renewal__c',
                    placeholder: 'Select Type...',
                    options: this.computedTypes,
                },
                initialWidth: 160,
                editable: true,
            },
            {
                label: 'Start Date',
                fieldName: 'License_Start_date__c',
                type: 'date-local',
                initialWidth: 155,
                editable: true,
            },
            {
                label: 'End Date',
                fieldName: 'License_end_date__c',
                type: 'date-local',
                initialWidth: 155,
                editable: true,
            },
            {
                label: 'Additional Info',
                fieldName: 'Additional_Info__c',
                type: 'text',
                initialWidth: 160,
                editable: true,
            },
            {
                label: 'LIC: Editable Unit List Price in USD',
                fieldName: 'Editable_Unit_List_Price_in_USD__c',
                type: 'currency',
                typeAttributes: {
                    currencyCode: 'USD',
                },
                initialWidth: 150,
                editable: true,
            },
            {
                label: 'LIC: Editable Cost Price in USD',
                fieldName: 'Editable_Cost_Price_in_Dollars__c',
                type: 'currency',
                typeAttributes: {
                    currencyCode: 'USD',
                },
                initialWidth: 150,
                editable: true,
            },
            {
                label: 'LIC: SEN',
                fieldName: 'SEN__c',
                type: 'text',
                initialWidth: 160,
                editable: true,
            },
            {
                label: "User Count",
                fieldName: "User_Count__c",
                type: "integer",
                initialWidth: 120,
                sortable: true,
                cellAttributes: {
                    alignment: "right"
                },
                editable: true,
            },
            {
                label: 'LIC: Unusual Discount Reviewed',
                fieldName: 'Unusual_discount_reviewed__c',
                type: 'boolean',
                initialWidth: 140,
                editable: true,
            },
            {
                label: 'LIC: Loss Reviewed',
                fieldName: 'Loss_Reviewed__c',
                type: 'boolean',
                initialWidth: 140,
                editable: true,
            },
        ];
        if (this.isDeletable) {
            this.opportunityLineItemColumns.unshift({
                label: '',
                type: 'button-icon',
                fixedWidth: 70,
                typeAttributes: {
                    iconName: 'utility:delete',
                    alternativeText: 'Delete',
                    name: 'delete',
                    title: 'Delete',
                },
            });
        }
    }

    get isOpportunityLineItemsEmpty() {
        return !this.opportunityLineItems?.length;
    }

    get computedTypes() {
        return [{ label: '--None--', value: '' }, ...this.types];
    }
}
