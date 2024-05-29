import LightningDatatable from "lightning/datatable";

import eficodeDatatablePicklistReadTemplate from "./eficodeDatatablePicklistReadTemplate.html";
import eficodeDatatablePicklistEditTemplate from "./eficodeDatatablePicklistEditTemplate.html";
import eficodeDatatableContactReadTemplate from "./eficodeDatatableContactReadTemplate.html";
import eficodeDatatableContactEditTemplate from "./eficodeDatatableContactEditTemplate.html";
import eficodeDatatableDiscountReadTemplate from "./eficodeDatatableDiscountReadTemplate.html";
import eficodeDatatableDiscountEditTemplate from "./eficodeDatatableDiscountEditTemplate.html";

export default class EficodeDatatable extends LightningDatatable {
  static customTypes = {
    picklist: {
      template: eficodeDatatablePicklistReadTemplate,
      editTemplate: eficodeDatatablePicklistEditTemplate,
      standardCellLayout: true,
      typeAttributes: ["placeholder", "options", "name"]
    },
    contact: {
      template: eficodeDatatableContactReadTemplate,
      editTemplate: eficodeDatatableContactEditTemplate,
      standardCellLayout: true,
      typeAttributes: ["placeholder", "name", "contactName"]
    },
    discount: {
      template: eficodeDatatableDiscountReadTemplate,
      editTemplate: eficodeDatatableDiscountEditTemplate,
      standardCellLayout: true,
      typeAttributes: ["name"]
    }
  };
}