export const TOC_FIXED_MIN_TOP_PX = 16
const TOC_FIXED_BOTTOM_PADDING_PX = 16

export function resolveTocFixedTopPx(columnTop, cachedTopPx) {
    if (cachedTopPx !== null && cachedTopPx !== undefined) {
        return cachedTopPx
    }

    return Math.max(columnTop, TOC_FIXED_MIN_TOP_PX)
}

export function applyTocFixedLayout(columnElement, tocElement, listElement, options = {}) {
    if (!columnElement || !tocElement) {
        return { applied: false, topPx: null }
    }

    const rect = columnElement.getBoundingClientRect()
    if (rect.width < 1) {
        clearTocFixedLayout(tocElement)
        return { applied: false, topPx: null }
    }

    const topPx = resolveTocFixedTopPx(rect.top, options.cachedTopPx)

    if (listElement) {
        listElement.scrollTop = 0
    }

    tocElement.style.position = 'fixed'
    tocElement.style.top = `${topPx}px`
    tocElement.style.left = `${rect.left}px`
    tocElement.style.width = `${rect.width}px`
    tocElement.style.maxHeight = `calc(100vh - ${topPx + TOC_FIXED_BOTTOM_PADDING_PX}px)`
    return { applied: true, topPx }
}

export function clearTocFixedLayout(tocElement) {
    if (!tocElement) {
        return
    }

    tocElement.style.position = ''
    tocElement.style.top = ''
    tocElement.style.left = ''
    tocElement.style.width = ''
    tocElement.style.maxHeight = ''
}