import { LightningElement, api } from "lwc";

export default class EficodeDatatablePicklistLabel extends LightningElement {
  @api options;
  @api value;

  get computedValue() {
    const options = Array.isArray(this.options)
      ? this.options
      : Object.values(this.options);
    return options.find(
      (option) => option?.value === this.value || option?.label === this.value
    )?.label;
  }
}