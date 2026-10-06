import { LightningElement, api } from 'lwc'

function splitTextForHighlight(text, highlightTerm, keyPrefix) {
    if (!highlightTerm || !text) {
        return [{ key: `${keyPrefix}-0`, text, isText: true }]
    }

    const lowerText = text.toLowerCase()
    const lowerTerm = highlightTerm.toLowerCase()
    const parts = []
    let startIndex = 0
    let partIndex = 0

    while (startIndex < text.length) {
        const matchIndex = lowerText.indexOf(lowerTerm, startIndex)

        if (matchIndex === -1) {
            parts.push({
                key: `${keyPrefix}-${partIndex}`,
                text: text.slice(startIndex),
                isText: true,
            })
            break
        }

        if (matchIndex > startIndex) {
            parts.push({
                key: `${keyPrefix}-${partIndex}`,
                text: text.slice(startIndex, matchIndex),
                isText: true,
            })
            partIndex += 1
        }

        parts.push({
            key: `${keyPrefix}-${partIndex}`,
            text: text.slice(matchIndex, matchIndex + highlightTerm.length),
            isHighlight: true,
        })
        partIndex += 1
        startIndex = matchIndex + highlightTerm.length
    }

    return parts.length ? parts : [{ key: `${keyPrefix}-0`, text, isText: true }]
}

export default class FbMarkdownInline extends LightningElement {
    @api parts = []
    @api highlightTerm

    get renderedParts() {
        if (!this.highlightTerm) {
            return this.parts
        }

        return this.parts.flatMap((part) => {
            if (part.isText) {
                return splitTextForHighlight(part.text, this.highlightTerm, part.key)
            }

            if (part.isStrong || part.isEmphasis || part.isCode) {
                return splitTextForHighlight(part.text, this.highlightTerm, part.key).map((highlightPart) => ({
                    ...highlightPart,
                    isStrong: part.isStrong && !highlightPart.isHighlight,
                    isEmphasis: part.isEmphasis && !highlightPart.isHighlight,
                    isCode: part.isCode && !highlightPart.isHighlight,
                    isText: highlightPart.isText,
                }))
            }

            return [part]
        })
    }

    handleLinkClick(event) {
        const docPath = event.currentTarget.dataset.docPath
        const anchor = event.currentTarget.dataset.anchor
        if (!docPath && !anchor) {
            return
        }

        event.preventDefault()
        this.dispatchEvent(
            new CustomEvent('doclink', {
                detail: { docPath, anchor },
                bubbles: true,
                composed: true,
            })
        )
    }
}