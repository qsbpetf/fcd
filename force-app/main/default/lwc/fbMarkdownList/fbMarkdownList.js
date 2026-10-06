import { LightningElement, api } from 'lwc'

export default class FbMarkdownList extends LightningElement {
    @api items = []
    @api ordered = false
    @api highlightTerm

    get hasItems() {
        return Array.isArray(this.items) && this.items.length > 0
    }
}