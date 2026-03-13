import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import { RefreshEvent } from "lightning/refresh";

import CurrencyIsoCode from "@salesforce/schema/Opportunity.CurrencyIsoCode";
import getOpportunityLineItems from "@salesforce/apex/OpportunityLineItemController.getOpportunityLineItems";
import getColumnConfig from "@salesforce/apex/OpportunityLineItemController.getColumnConfig";
import getPicklistValuesForFields from "@salesforce/apex/OpportunityLineItemController.getPicklistValuesForFields";

import OpportunityLineItemsAddModal from "c/opportunityLineItemsAddModal";
import OpportunityLineItemsEditModal from "c/opportunityLineItemsEditModal";
import OpportunityLineItemsDeleteModal from "c/opportunityLineItemsDeleteModal";

import { disableBodyScroll, enableBodyScroll } from "c/windowUtils";
import { formatOpportunityLineItems } from "c/formatUtils";

const DEFAULT_COLUMN_CONFIG = [
    { fieldApiName: "Url", label: "Product", type: "url", sortOrder: 10, initialWidth: 260, sortable: false, queryFieldApiNames: "PricebookEntry.Product2.Name,PricebookEntry.Product2.Id,PricebookEntry.Product2.Revenue_Type__c,PricebookEntry.Product2Id,PricebookEntry.Id", typeAttributesJson: "{\"label\":{\"fieldName\":\"PricebookEntry.Product2.Name\"},\"tooltip\":{\"fieldName\":\"PricebookEntry.Product2.Name\"}}" },
    { fieldApiName: "PricebookEntry.Product2.Unit_of_Measure__c", label: "Unit of Measure", type: "text", sortOrder: 20, initialWidth: 96, sortable: true },
    { fieldApiName: "Quantity", label: "Quantity", type: "number", sortOrder: 30, initialWidth: 96, sortable: true },
    { fieldApiName: "UnitPrice", label: "Unit Price", type: "currency", sortOrder: 40, initialWidth: 150, sortable: true, currencyCode: "OPPORTUNITY" },
    { fieldApiName: "Discount__c", label: "Discount", type: "discount", sortOrder: 50, initialWidth: 100, sortable: true, typeAttributesJson: "{\"name\":\"Discount__c\"}", cellAttributesJson: "{\"alignment\":\"right\"}" },
    { fieldApiName: "Total_List_Price_Incl_Discount__c", label: "Total Sales Price Inc. Discount", type: "currency", sortOrder: 60, initialWidth: 150, sortable: true, currencyCode: "OPPORTUNITY" },
    { fieldApiName: "Renewal__c", label: "Type", type: "picklist", sortOrder: 70, initialWidth: 160, sortable: true, picklistFieldApiName: "Renewal__c", typeAttributesJson: "{\"name\":\"Renewal__c\",\"placeholder\":\"Select Type...\"}" },
    { fieldApiName: "License_Start_date__c", label: "Start Date", type: "date-local", sortOrder: 80, initialWidth: 155, sortable: true },
    { fieldApiName: "License_end_date__c", label: "End Date", type: "date-local", sortOrder: 90, initialWidth: 155, sortable: true },
    { fieldApiName: "Additional_Info__c", label: "Additional Info", type: "text", sortOrder: 100, initialWidth: 160, sortable: true },
    { fieldApiName: "Editable_Unit_List_Price_in_USD__c", label: "LIC: Editable Unit List Price in USD", type: "currency", sortOrder: 110, initialWidth: 160, sortable: true, currencyCode: "USD" },
    { fieldApiName: "Editable_Cost_Price_in_Dollars__c", label: "LIC: Editable Cost Price in USD", type: "currency", sortOrder: 120, initialWidth: 160, sortable: true, currencyCode: "USD" },
    { fieldApiName: "SEN__c", label: "LIC: SEN", type: "text", sortOrder: 130, initialWidth: 160, sortable: true },
    { fieldApiName: "User_Count__c", label: "User Count", type: "integer", sortOrder: 140, initialWidth: 120, sortable: true, cellAttributesJson: "{\"alignment\":\"right\"}" },
    { fieldApiName: "Unusual_discount_reviewed__c", label: "LIC: Unusual Discount Reviewed", type: "boolean", sortOrder: 150, initialWidth: 140, sortable: true },
    { fieldApiName: "Loss_Reviewed__c", label: "LIC: Loss Reviewed", type: "boolean", sortOrder: 160, initialWidth: 140, sortable: true }
];

export default class OpportunityLineItemList extends LightningElement {
    @api recordId;

    @track opportunityLineItemColumns = [];
    @track opportunityLineItems = [];
    @track selectedRows = [];
    @track picklistOptionsByField = {};
    @track opportunity = {};
    @track columnConfig = [];

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
            this.handleOpportunityLineItemColumnsSet();
            this.handleOpportunityLineItemsGet();
        } else if (error) {
            console.error("getRecord error:", error);
            this.isFetching = false;
        }
    }

    @wire(getColumnConfig) getColumnConfigWire({data, error}) {
        if (data) {
            this.columnConfig = Array.isArray(data) ? data : [];
            this.fetchPicklistOptions()
                .then(() => {
                    this.handleOpportunityLineItemColumnsSet();
                    if (this.recordId) {
                        this.handleOpportunityLineItemsGet();
                    }
                })
                .catch((e) => {
                    console.error("fetchPicklistOptions error:", e);
                    this.handleOpportunityLineItemColumnsSet();
                    if (this.recordId) {
                        this.handleOpportunityLineItemsGet();
                    }
                });
        } else if (error) {
            console.error("getColumnConfig error:", error);
            this.columnConfig = [];
            this.handleOpportunityLineItemColumnsSet();
            if (this.recordId) {
                this.handleOpportunityLineItemsGet();
            }
        }
    }

    async fetchPicklistOptions() {
        const configs = this.columnConfig?.length > 0 ? this.columnConfig : DEFAULT_COLUMN_CONFIG;
        const picklistFields = [
            ...new Set(
                configs
                    ?.filter((c) => c.picklistFieldApiName)
                    ?.map((c) => c.picklistFieldApiName) ?? []
            )
        ];
        if (picklistFields.length === 0) {
            this.picklistOptionsByField = {};
            return Promise.resolve();
        }
        try {
            const result = await getPicklistValuesForFields({ fieldApiNames: picklistFields });
            this.picklistOptionsByField = result ?? {};
        } catch (e) {
            console.error(e);
            this.picklistOptionsByField = {};
        }
        return Promise.resolve();
    }

    connectedCallback() {
        this.handleOpportunityLineItemColumnsSet();
    }

    get effectiveColumnConfigs() {
        return this.columnConfig?.length > 0 ? this.columnConfig : DEFAULT_COLUMN_CONFIG;
    }

    get effectiveColumnConfigForDisplay() {
        return this.columnConfig?.length > 0 ? this.columnConfig : DEFAULT_COLUMN_CONFIG;
    }

    async handleOpportunityLineItemsGet() {
        if (!this.recordId) {
            return;
        }
        this.isFetching = true;
        this.start = 0;
        try {
            const {count, olis} = await getOpportunityLineItems({
                oppId: this.recordId,
                start: this.start,
                pageSize: this.pageSize,
                sortBy: this.sortBy,
                sortDirection: this.sortDirection,
                columnConfigs: this.effectiveColumnConfigs
            });
            this.count = count;
            this.opportunityLineItems = formatOpportunityLineItems(olis);
        } catch (e) {
            console.error("handleOpportunityLineItemsGet error:", e);
            this.opportunityLineItems = [];
            this.count = 0;
        } finally {
            this.isFetching = false;
        }
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
        try {
            const {count, olis} = await getOpportunityLineItems({
                oppId: this.recordId,
                start: this.start,
                pageSize: this.pageSize,
                sortBy: this.sortBy,
                sortDirection: this.sortDirection,
                columnConfigs: this.effectiveColumnConfigs
            });
            this.count = count;
            this.opportunityLineItems = [...this.opportunityLineItems]?.concat(
                formatOpportunityLineItems(olis)
            );
        } catch (e) {
            console.error("handleOpportunityLineItemsLoadMore error:", e);
            this.start -= this.pageSize;
        } finally {
            datatable.isLoading = false;
        }
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
        const configs = this.effectiveColumnConfigForDisplay;
        if (!configs?.length) {
            this.opportunityLineItemColumns = [];
            return;
        }
        this.opportunityLineItemColumns = configs.map((config) =>
            this.buildColumnFromMetadata(config)
        );
    }

    buildColumnFromMetadata(config) {
        const col = {
            label: config.label ?? config.fieldApiName,
            fieldName: config.fieldApiName,
            type: config.type ?? "text",
            initialWidth: config.initialWidth ?? 120,
            sortable: config.sortable !== false
        };

        if (config.typeAttributesJson) {
            try {
                col.typeAttributes = JSON.parse(config.typeAttributesJson);
            } catch (e) {
                console.warn("Invalid typeAttributesJson:", config.typeAttributesJson);
            }
        }

        if (config.type === "currency" && config.currencyCode) {
            col.typeAttributes = col.typeAttributes || {};
            col.typeAttributes.currencyCode =
                config.currencyCode === "OPPORTUNITY"
                    ? this.opportunity?.CurrencyIsoCode
                    : config.currencyCode;
        }

        if (config.type === "picklist" && config.picklistFieldApiName) {
            col.typeAttributes = col.typeAttributes || {};
            const rawOptions = this.picklistOptionsByField[config.picklistFieldApiName] ?? [];
            col.typeAttributes.options = [{ label: "--None--", value: "" }, ...rawOptions];
            col.typeAttributes.name = config.fieldApiName;
            if (!col.typeAttributes.placeholder) {
                col.typeAttributes.placeholder = "Select...";
            }
        }

        if (config.cellAttributesJson) {
            try {
                col.cellAttributes = JSON.parse(config.cellAttributesJson);
            } catch (e) {
                console.warn("Invalid cellAttributesJson:", config.cellAttributesJson);
            }
        }

        return col;
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
}
