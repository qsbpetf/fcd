import { LightningElement, api } from "lwc";

export default class EficodeDatatablePicklist extends LightningElement {
  @api name;
  @api value;
  @api label;
  @api placeholder;
  @api options;
  @api required;

  @api get validity() {
    const select = this.template.querySelector("lightning-select");
    return select.validity;
  }

  @api showHelpMessageIfInvalid() {
    const select = this.template.querySelector("lightning-select");
    select.showHelpMessageIfInvalid();
  }

  @api focus() {
    const select = this.template.querySelector("lightning-select");
    select.focus();
  }

  @api blur() {
    const select = this.template.querySelector("lightning-select");
    select.blur();
  }

  get computedOptions() {
    const options = Array.isArray(this.options)
      ? this.options
      : Object.values(this.options);
    return options;
  }

  handleOutsideClick() {
    this.handleModalClose();
  }

  handleModalClose() {
    const button = this.template.querySelector('button[type="submit"]');
    button.click();
  }

  handleChange(event) {
    event.stopPropagation();
    const nextValue = event.detail.value;
    // eslint-disable-next-line @lwc/lwc/no-api-reassignments
    this.value = nextValue;
    this.handleModalClose();
  }

  handleOptionLabelFind(value) {
    let label = "";
    const options = this.computedOptions;
    if (options) {
      label = options.find((option) => option?.value === value)?.label;
    }
    return label;
  }
}