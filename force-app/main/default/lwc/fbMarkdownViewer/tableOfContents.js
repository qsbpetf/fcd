import { extractTextFromParts } from './markdownText'

export const TOC_ACTIVATION_OFFSET = 120
export const TOC_NEAR_BAND = 150
export const TOC_PASSED_THRESHOLD = -50

export function resolveActiveTocBlockKey(tableOfContents = [], getSectionTop) {
    if (!tableOfContents.length || typeof getSectionTop !== 'function') {
        return null
    }

    let passedKey = tableOfContents[0].blockKey
    let nearestBelowKey = null
    let nearestBelowTop = Infinity

    for (const entry of tableOfContents) {
        const top = getSectionTop(entry.blockKey)

        if (top === null || top === undefined) {
            continue
        }

        if (top <= TOC_ACTIVATION_OFFSET) {
            passedKey = entry.blockKey
        }

        if (top > TOC_ACTIVATION_OFFSET && top < nearestBelowTop) {
            nearestBelowTop = top
            nearestBelowKey = entry.blockKey
        }
    }

    const passedTop = getSectionTop(passedKey)

    if (
        nearestBelowKey &&
        nearestBelowTop <= TOC_ACTIVATION_OFFSET + TOC_NEAR_BAND &&
        passedTop !== null &&
        passedTop !== undefined &&
        passedTop < TOC_PASSED_THRESHOLD
    ) {
        return nearestBelowKey
    }

    return passedKey
}

export function extractTableOfContents(blocks = []) {
    return blocks
        .filter((block) => block.isHeading1 || block.isHeading2 || block.isHeading3)
        .map((block) => ({
            key: block.key,
            blockKey: block.key,
            anchorId: block.anchorId || block.key,
            label: extractTextFromParts(block.parts).trim(),
            level: block.isHeading1 ? 1 : block.isHeading2 ? 2 : 3,
        }))
        .filter((entry) => entry.label)
}

export function buildTableOfContentsView(entries = [], activeBlockKey = null) {
    return entries.map((entry) => {
        const isActive = entry.blockKey === activeBlockKey

        return {
            ...entry,
            itemClass: `toc-item toc-level-${entry.level}${isActive ? ' toc-item-active' : ''}`,
            buttonClass: `toc-button${isActive ? ' toc-button-active' : ''}`,
        }
    })
}