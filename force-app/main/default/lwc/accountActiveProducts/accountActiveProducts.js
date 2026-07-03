import { LightningElement, api, wire } from 'lwc';
import getActiveProducts from '@salesforce/apex/AccountActiveProductsController.getActiveProducts';

const COLUMNS = [
    {
        label: 'Product Name',
        fieldName: 'productName',
        type: 'text',
        sortable: true
    },
    {
        label: 'Start Date',
        fieldName: 'License_Start_date__c',
        type: 'date',
        sortable: true,
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }
    },
    {
        label: 'End Date',
        fieldName: 'License_end_date__c',
        type: 'date',
        sortable: true,
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }
    },
    {
        label: 'Quantity',
        fieldName: 'Quantity',
        type: 'number',
        sortable: true
    },
    {
        label: 'User Count',
        fieldName: 'User_Count__c',
        type: 'number',
        sortable: true
    },
    {
        label: 'Product Type',
        fieldName: 'Renewal__c',
        type: 'text',
        sortable: true
    },
    {
        label: 'Opportunity',
        fieldName: 'opportunityLink',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'opportunityName' },
            target: '_blank'
        }
    }
];

export default class AccountActiveProducts extends LightningElement {

    @api recordId;

    products = [];
    error;
    isLoading = true;
    columns = COLUMNS;
    sortedBy = 'License_end_date__c';
    sortedDirection = 'desc';

    @wire(getActiveProducts, { accountId: '$recordId' })
    wiredProducts({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.products = data.map(item => ({
                ...item,
                id: item.Id,
                productName: item.Product2 ? item.Product2.Name : '',
                opportunityName: item.Opportunity ? item.Opportunity.Name : '',
                opportunityLink: item.Opportunity
                    ? '/' + item.Opportunity.Id
                    : ''
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.products = [];
        }
    }

    get hasProducts() {
        return this.products && this.products.length > 0;
    }

    get productCount() {
        return this.products ? this.products.length : 0;
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;

        const clonedData = [...this.products];
        clonedData.sort(this.sortBy(fieldName, sortDirection === 'asc' ? 1 : -1));
        this.products = clonedData;
    }

    sortBy(field, reverse) {
        const key = (a) => {
            let value = a[field];
            if (typeof value === 'string') {
                value = value.toLowerCase();
            }
            return value;
        };
        return (a, b) => {
            const aVal = key(a);
            const bVal = key(b);
            if (aVal === undefined || aVal === null) return reverse;
            if (bVal === undefined || bVal === null) return -reverse;
            if (aVal < bVal) return -1 * reverse;
            if (aVal > bVal) return 1 * reverse;
            return 0;
        };
    }
}