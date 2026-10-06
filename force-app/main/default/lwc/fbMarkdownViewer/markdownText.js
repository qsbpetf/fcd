export function extractTextFromParts(parts = []) {
    return parts
        .map((part) => {
            if (part.isText) {
                return part.text
            }

            if (part.isLink) {
                return part.label
            }

            if (part.isStrong || part.isEmphasis || part.isCode) {
                return part.text
            }

            return ''
        })
        .join('')
}

export function extractListText(items = []) {
    return items
        .map((item) => {
            const itemText = extractTextFromParts(item.parts)
            const childText = item.children?.length ? extractListText(item.children) : ''
            return [itemText, childText].filter(Boolean).join(' ')
        })
        .join(' ')
}