import { LightningElement, api } from "lwc";

import getContacts from "@salesforce/apex/ContactController.getContacts";

export default class EficodeDatatableContactAutocomplete extends LightningElement {
  @api label;
  @api placeholder;
  @api value;
  @api name;
  @api required;
  @api contactName;

  @api get validity() {
    const input = this.template.querySelector("lightning-input");
    return input.validity;
  }

  @api showHelpMessageIfInvalid() {
    const input = this.template.querySelector("lightning-input");
    input.showHelpMessageIfInvalid();
  }

  @api focus() {
    const input = this.template.querySelector("lightning-input");
    input.focus();
  }

  @api blur() {
    const input = this.template.querySelector("lightning-input");
    input.blur();
  }

  contacts = [];
  wildcardTimeout = undefined;
  isFocused = false;
  isOpen = false;
  isFetching = false;

  handleInputChange(event) {
    const wildcard = event.detail.value;
    this.wildcard = wildcard;
    clearTimeout(this.wildcardTimeout);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.wildcardTimeout = window.setTimeout(() => {
      this.handleContactsGet();
    }, 300);
  }

  async handleContactsGet() {
    this.isFetching = true;
    const { count, cs } = await getContacts({
      start: 0,
      pageSize: 40,
      sortBy: "Name",
      sortDirection: "asc",
      wildcard: this.wildcard
    });
    this.count = count;
    this.contacts = cs;
    this.isFetching = false;
  }

  handleOptionSelect(event) {
    event.stopPropagation();
    const nextValue = event?.currentTarget?.dataset?.value;
    const nextLabel = event?.currentTarget?.dataset?.label;
    // eslint-disable-next-line @lwc/lwc/no-api-reassignments
    this.value = `${nextValue}|${nextLabel}`;
    this.isFocused = false;
    this.isOpen = false;
    this.handleModalClose();
  }

  handleOutsideClick() {
    if (!this.isFocused && this.isOpen) {
      this.isOpen = false;
    }
    this.handleModalClose();
  }

  handleFocus() {
    this.isFocused = true;
    this.isOpen = true;
  }

  handleBlur() {
    this.isFocused = false;
  }

  handleModalClose() {
    const button = this.template.querySelector('button[type="submit"]');
    button.click();
  }

  get computedContactName() {
    if (this.value?.includes("|")) {
      const [, contactName] = this.value.split("|");
      return contactName;
    }
    return this.contactName;
  }

  get computedOptions() {
    return [...this.contacts].map((contact) => ({
      label: contact?.Name,
      value: contact?.Id
    }));
  }

  get isOptionsEmpty() {
    return this.computedOptions.length === 0;
  }

  get dropdownClasses() {
    let dropdownClasses =
      "slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click";
    if (this.isOpen) {
      dropdownClasses += " slds-is-open";
    }
    return dropdownClasses;
  }
}