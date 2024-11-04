import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { RefreshEvent } from "lightning/refresh";

import CurrencyIsoCode from "@salesforce/schema/Opportunity.CurrencyIsoCode";
import getOpportunityLineItems from "@salesforce/apex/OpportunityLineItemController.getOpportunityLineItems";
import getTypePicklistValues from "@salesforce/apex/OpportunityLineItemController.getTypePicklistValues";

import OpportunityLineItemsAddModal from "c/opportunityLineItemsAddModal";
import OpportunityLineItemsEditModal from "c/opportunityLineItemsEditModal";
import OpportunityLineItemsDeleteModal from "c/opportunityLineItemsDeleteModal";

import { disableBodyScroll, enableBodyScroll } from "c/windowUtils";
import { formatOpportunityLineItems } from "c/formatUtils";

export default class OpportunityLineItemList extends LightningElement {
    @api recordId;

    @track opportunityLineItemColumns = [];
    @track opportunityLineItems = [];
    @track selectedRows = [];
    @track types = [];
    @track opportunity = {};

    start = 0;
    pageSize = 30;
    count = 0;
    sortBy = "PricebookEntry.Product2.Name";
    sortDirection = "asc";
    isFetching = false;

    @wire(getRecord, {
        recordId: "$recordId",
        fields: [CurrencyIsoCode]
    })
    getOpportunityRecord({data, error}) {
        if (data) {
            this.opportunity = {
                CurrencyIsoCode: getFieldValue(data, CurrencyIsoCode)
            };
            this.handleOpportunityLineItemsGet();
            this.handleOpportunityLineItemColumnsSet();
        } else if (error) {
            console.error(error);
        }
    }

    @wire(getTypePicklistValues) getTypePicklistValuesWire({data, error}) {
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

    async handleOpportunityLineItemsGet() {
        this.isFetching = true;
        this.start = 0;
        const {count, olis} = await getOpportunityLineItems({
            oppId: this.recordId,
            start: this.start,
            pageSize: this.pageSize,
            sortBy: this.sortBy,
            sortDirection: this.sortDirection
        });
        this.count = count;
        this.opportunityLineItems = formatOpportunityLineItems(olis);
        this.isFetching = false;
    }

    handleSelectedRowsReset() {
        this.selectedRows = [];
    }

    handlePageRefresh() {
        const refreshEvent = new RefreshEvent();
        this.dispatchEvent(refreshEvent);
    }

    async handleOpportunityLineItemsAdd() {
        disableBodyScroll();
        const result = await OpportunityLineItemsAddModal.open({
            size: "large",
            opportunityId: this.recordId
        });
        enableBodyScroll();

        if (result === "submit") {
            this.handleOpportunityLineItemsGet();
            this.handleSelectedRowsReset();
            this.handlePageRefresh();
        }
    }

    async handleOpportunityLineItemsEdit() {
        disableBodyScroll();
        const result = await OpportunityLineItemsEditModal.open({
            size: "large",
            opportunityId: this.recordId,
            opportunityLineItemIds: this.selectedRows
        });
        enableBodyScroll();

        if (result === "submit") {
            this.handleOpportunityLineItemsGet();
            this.handleSelectedRowsReset();
            this.handlePageRefresh();
        }
    }

    async handleOpportunityLineItemsDelete() {
        disableBodyScroll();
        const result = await OpportunityLineItemsDeleteModal.open({
            size: "small",
            opportunityId: this.recordId,
            opportunityLineItemIds: this.selectedRows
        });
        enableBodyScroll();

        if (result === "submit") {
            this.handleOpportunityLineItemsGet();
            this.handleSelectedRowsReset();
            this.handlePageRefresh();
        }
    }

    async handleOpportunityLineItemsLoadMore(event) {
        const datatable = event?.target;
        if (!datatable) {
            return;
        }
        if (this.count <= this.start + this.pageSize) {
            return;
        }

        datatable.isLoading = true;
        this.start += this.pageSize;
        const {count, olis} = await getOpportunityLineItems({
            oppId: this.recordId,
            start: this.start,
            pageSize: this.pageSize,
            sortBy: this.sortBy,
            sortDirection: this.sortDirection
        });
        this.count = count;
        this.opportunityLineItems = [...this.opportunityLineItems]?.concat(
            formatOpportunityLineItems(olis)
        );
        datatable.isLoading = false;
    }

    handleOpportunityLineItemsSort(event) {
        const sortBy = event.detail.fieldName;
        const sortDirection = event.detail.sortDirection;
        if (this.sortBy !== sortBy || this.sortDirection !== sortDirection) {
            this.sortBy = sortBy;
            this.sortDirection = sortDirection;
            this.handleOpportunityLineItemsGet();
        }
    }

    handleOpportunityLineItemsRowSelection(event) {
        const selectedRows = event?.detail?.selectedRows?.map(
            (selectedRow) => selectedRow?.Id
        );
        this.selectedRows = selectedRows;
    }

    handleOpportunityLineItemColumnsSet() {
        this.opportunityLineItemColumns = [
            {
                label: "Product",
                fieldName: "Url",
                type: "url",
                typeAttributes: {
                    label: {fieldName: "PricebookEntry.Product2.Name"},
                    tooltip: {fieldName: "PricebookEntry.Product2.Name"}
                },
                initialWidth: 260
            },
            {
                label: "Unit of Measure",
                fieldName: "PricebookEntry.Product2.Unit_of_Measure__c",
                type: "text",
                initialWidth: 96,
                sortable: true
            },
            {
                label: "Quantity",
                fieldName: "Quantity",
                type: "number",
                initialWidth: 96,
                sortable: true
            },
            {
                label: "Unit Price",
                fieldName: "UnitPrice",
                type: "currency",
                typeAttributes: {
                    currencyCode: this.opportunity?.CurrencyIsoCode
                },
                initialWidth: 150,
                sortable: true
            },
            {
                label: "Discount",
                fieldName: "Discount__c",
                type: "discount",
                typeAttributes: {
                    name: "Discount__c"
                },
                cellAttributes: {
                    alignment: "right"
                },
                initialWidth: 100,
                sortable: true
            },
            {
                label: "Total Sales Price Inc. Discount",
                fieldName: "Total_List_Price_Incl_Discount__c",
                type: "currency",
                typeAttributes: {
                    currencyCode: this.opportunity?.CurrencyIsoCode
                },
                initialWidth: 150,
                sortable: true
            },
            {
                label: "Type",
                fieldName: "Renewal__c",
                type: "picklist",
                typeAttributes: {
                    name: "Renewal__c",
                    placeholder: "Select Type...",
                    options: this.computedTypes
                },
                initialWidth: 160,
                sortable: true
            },
            {
                label: "Start Date",
                fieldName: "License_Start_date__c",
                type: "date-local",
                initialWidth: 155,
                sortable: true
            },
            {
                label: "End Date",
                fieldName: "License_end_date__c",
                type: "date-local",
                initialWidth: 155,
                sortable: true
            },
            {
                label: "Additional Info",
                fieldName: "Additional_Info__c",
                type: "text",
                initialWidth: 160,
                sortable: true
            },
            {
                label: "LIC: Editable Unit List Price in USD",
                fieldName: "Editable_Unit_List_Price_in_USD__c",
                type: "currency",
                typeAttributes: {
                    currencyCode: "USD"
                },
                initialWidth: 160,
                sortable: true
            },
            {
                label: "LIC: Editable Cost Price in USD",
                fieldName: "Editable_Cost_Price_in_Dollars__c",
                type: "currency",
                typeAttributes: {
                    currencyCode: "USD"
                },
                initialWidth: 160,
                sortable: true
            },
            {
                label: "LIC: SEN",
                fieldName: "SEN__c",
                type: "text",
                initialWidth: 160,
                sortable: true
            },
            {
                label: "User Count",
                fieldName: "User_Count__c",
                type: "integer",
                initialWidth: 120,
                sortable: true,
                cellAttributes: {
                    alignment: "right"
                }
            },
            {
                label: "LIC: Unusual Discount Reviewed",
                fieldName: "Unusual_discount_reviewed__c",
                type: "boolean",
                initialWidth: 140,
                sortable: true
            },
            {
                label: "LIC: Loss Reviewed",
                fieldName: "Loss_Reviewed__c",
                type: "boolean",
                initialWidth: 140,
                sortable: true
            }
        ];
    }

    get isOpportunityLineItemsEmpty() {
        return this.opportunityLineItems?.length === 0;
    }

    get isSelectedRowsEmpty() {
        return this.selectedRows?.length === 0;
    }

    get selectedRowsCount() {
        return this.selectedRows?.length;
    }

    get computedTypes() {
        return [{label: "--None--", value: ""}, ...this.types];
    }
}