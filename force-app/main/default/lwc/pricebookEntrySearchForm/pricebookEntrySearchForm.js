import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";

import CurrencyIsoCode from "@salesforce/schema/Opportunity.CurrencyIsoCode";
import getPricebookEntries from "@salesforce/apex/PricebookEntryController.getPricebookEntries";
import getRevenueTypePicklistValues from "@salesforce/apex/ProductController.getRevenueTypePicklistValues";
import getProductFamilyPicklistValues from "@salesforce/apex/ProductController.getProductFamilyPicklistValues";
import getBusinessAreaPicklistValues from "@salesforce/apex/ProductController.getBusinessAreaPicklistValues";

import { formatPricebookEntries } from "c/formatUtils";

export default class OpportunitySearchProductsForm extends LightningElement {
  @api opportunityId;
  @api opportunityLineItems = [];

  @track pricebookEntryColumns = [];
  @track pricebookEntries = [];
  @track revenueTypes = [];
  @track productFamilies = [];
  @track businessAreas = [];
  @track opportunity = {};

  start = 0;
  pageSize = 30;
  count = 0;
  sortBy = "Product2.Name";
  sortDirection = "asc";
  wildcard = "";
  wildcardTimeout = undefined;
  revenueType = "";
  productFamily = "";
  businessArea = "";

  @wire(getRecord, {
    recordId: "$opportunityId",
    fields: [CurrencyIsoCode]
  })
  getOpportunityRecord({ data, error }) {
    if (data) {
      this.opportunity = {
        CurrencyIsoCode: getFieldValue(data, CurrencyIsoCode)
      };
      this.handlePricebookEntriesGet();
      this.handlePricebookEntryColumnsSet();
    } else if (error) {
      console.error(error);
    }
  }

  @wire(getRevenueTypePicklistValues) getRevenueTypePicklistValuesWire({
    data,
    error
  }) {
    if (data) {
      this.revenueTypes = data;
    } else if (error) {
      console.error(error);
    }
  }

  @wire(getProductFamilyPicklistValues) getProductFamilyPicklistValuesWire({
    data,
    error
  }) {
    if (data) {
      this.productFamilies = data;
    } else if (error) {
      console.error(error);
    }
  }

  @wire(getBusinessAreaPicklistValues) getBusinessAreaPicklistValuesWire({
    data,
    error
  }) {
    if (data) {
      this.businessAreas = data;
    } else if (error) {
      console.error(error);
    }
  }

  connectedCallback() {
    this.handlePricebookEntryColumnsSet();
  }

  async handlePricebookEntriesGet() {
    this.start = 0;
    const { count, pbes } = await getPricebookEntries({
      oppId: this.opportunityId,
      start: this.start,
      pageSize: this.pageSize,
      sortBy: this.sortBy,
      sortDirection: this.sortDirection,
      wildcard: this.wildcard,
      revenueType: this.revenueType,
      productFamily: this.productFamily,
      businessArea: this.businessArea
    });
    this.count = count;
    this.pricebookEntries = formatPricebookEntries(pbes);
  }

  handleWildcardChange(event) {
    this.wildcard = event.target.value;
    window.clearTimeout(this.wildcardTimeout);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.wildcardTimeout = window.setTimeout(() => {
      this.start = 0;
      this.handlePricebookEntriesGet();
    }, 500);
  }

  handleRevenueTypeChange(event) {
    this.revenueType = event.target.value;
    this.start = 0;
    this.handlePricebookEntriesGet();
  }

  handleProductFamilyChange(event) {
    this.productFamily = event.target.value;
    this.start = 0;
    this.handlePricebookEntriesGet();
  }

  handleBusinessAreaChange(event) {
    this.businessArea = event.target.value;
    this.start = 0;
    this.handlePricebookEntriesGet();
  }

  handleSearchClick() {
    this.start = 0;
    this.handlePricebookEntriesGet();
  }

  handleClearFiltersClick() {
    this.start = 0;
    this.sortBy = "Product2.Name";
    this.sortDirection = "asc";
    this.wildcard = "";
    this.revenueType = "";
    this.productFamily = "";
    this.businessArea = "";
    this.handlePricebookEntriesGet();
  }

  handleOpportunityLineItemsChange(opportunityLineItems) {
    const event = new CustomEvent("opportunitylineitemschange", {
      detail: {
        value: opportunityLineItems
      }
    });
    this.dispatchEvent(event);
  }

  handlePricebookEntriesRowAction(event) {
    const pricebookEntry = event.detail.row;
    const opportunityLineItems = [...this.opportunityLineItems]?.concat({
      Id: this.handleUuidCreate(),
      OpportunityId: this.opportunityId,
      PricebookEntryId: pricebookEntry?.Id,
      PricebookEntry: pricebookEntry,
      UnitPrice: pricebookEntry?.UnitPrice,
      Quantity: 1,
      Name: undefined,
      Discount__c: undefined,
      License_Start_date__c: undefined,
      License_end_date__c: undefined,
      Additional_Info__c: undefined,
      Editable_Cost_Price_in_Dollars__c: undefined,
      Editable_Unit_List_Price_in_USD__c: undefined,
      SEN__c: undefined,
      SEN_Technical_Contact__c: undefined,
      Loss_Reviewed__c: undefined,
      Unusual_discount_reviewed__c: undefined
    });
    this.handleOpportunityLineItemsChange(opportunityLineItems);
  }

  async handlePricebookEntriesLoadMore(event) {
    const datatable = event?.target;
    if (!datatable) {
      return;
    }
    if (this.count <= this.start + this.pageSize) {
      return;
    }

    datatable.isLoading = true;
    this.start += this.pageSize;
    const { count, pbes } = await getPricebookEntries({
      oppId: this.opportunityId,
      start: this.start,
      pageSize: this.pageSize,
      sortBy: this.sortBy,
      sortDirection: this.sortDirection,
      wildcard: this.wildcard,
      revenueType: this.revenueType,
      productFamily: this.productFamily,
      businessArea: this.businessArea
    });
    this.count = count;
    this.pricebookEntries = [...this.pricebookEntries]?.concat(
      formatPricebookEntries(pbes)
    );
    datatable.isLoading = false;
  }

  handlePricebookEntriesSort(event) {
    const sortBy = event.detail.fieldName;
    const sortDirection = event.detail.sortDirection;
    if (this.sortBy !== sortBy || this.sortDirection !== sortDirection) {
      this.sortBy = sortBy;
      this.sortDirection = sortDirection;
      this.start = 0;
      this.handlePricebookEntriesGet();
    }
  }

  handleOpportunityItemDelete(event) {
    const opportunityLineItemId = event.target.dataset.opportunityLineItemId;
    const opportunityLineItems = [...this.opportunityLineItems]?.filter(
      (opportunityLineItem) => opportunityLineItem.Id !== opportunityLineItemId
    );
    this.handleOpportunityLineItemsChange(opportunityLineItems);
  }

  handleUuidCreate() {
    return "10000000-1000-4000-8000-100000000000".replace(/[018]/g, (c) => {
      return (
        c ^
        (crypto.getRandomValues(new Uint8Array(1))[0] & (15 >> (c / 4)))
      ).toString(16);
    });
  }

  handlePricebookEntryColumnsSet() {
    this.pricebookEntryColumns = [
      {
        label: "Product Name",
        fieldName: "Product2.Name",
        type: "text",
        sortable: true
      },
      {
        label: "Product Family",
        fieldName: "Product2.Family",
        type: "text",
        initialWidth: 220,
        sortable: true
      },
      {
        label: "Business Area",
        fieldName: "Product2.Business_Area__c",
        type: "text",
        initialWidth: 140,
        sortable: true
      },
      {
        label: "Unit of Measure",
        fieldName: "Product2.Unit_of_Measure__c",
        type: "text",
        initialWidth: 100,
        sortable: true
      },
      {
        label: "Unit Price",
        fieldName: "UnitPrice",
        type: "currency",
        typeAttributes: {
          currencyCode: this.opportunity?.CurrencyIsoCode
        },
        initialWidth: 120,
        sortable: true
      },
      {
        label: "",
        type: "button-icon",
        fixedWidth: 70,
        typeAttributes: {
          iconName: "utility:add",
          alternativeText: "Add",
          name: "add",
          title: "Add"
        }
      }
    ];
  }

  get isPricebookEntriesEmpty() {
    return this.pricebookEntries?.length === 0;
  }

  get isOpportunityLineItemsEmpty() {
    return this.opportunityLineItems?.length === 0;
  }

  get computedRevenueTypes() {
    return [{ label: "--None--", value: "" }, ...this.revenueTypes];
  }

  get computedProductFamilies() {
    return [{ label: "--None--", value: "" }, ...this.productFamilies];
  }

  get computedBusinessAreas() {
    return [{ label: "--None--", value: "" }, ...this.businessAreas];
  }
}