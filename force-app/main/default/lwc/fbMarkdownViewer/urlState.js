export const URL_STATE_KEYS = {
    DOC: 'c__doc',
    BLOCK: 'c__block',
    Q: 'c__q',
}

export function normalizeDocPath(docPath) {
    if (!docPath) {
        return null
    }

    let normalized = decodeURIComponent(String(docPath)).trim()

    if (!normalized) {
        return null
    }

    if (/^(https?:|\/)/i.test(normalized)) {
        return null
    }

    if (normalized.includes('..')) {
        return null
    }

    if (!/\.md$/i.test(normalized)) {
        normalized = `${normalized}.md`
    }

    return normalized
}

export function parseUrlState(pageRef) {
    const state = pageRef?.state || {}

    return {
        doc: normalizeDocPath(state[URL_STATE_KEYS.DOC]),
        block: state[URL_STATE_KEYS.BLOCK] || null,
        q: state[URL_STATE_KEYS.Q] || null,
    }
}

export function buildUrlState({ doc, block, q }, existingState = {}) {
    const state = { ...existingState }

    if (doc) {
        state[URL_STATE_KEYS.DOC] = doc
    } else {
        delete state[URL_STATE_KEYS.DOC]
    }

    if (block) {
        state[URL_STATE_KEYS.BLOCK] = block
    } else {
        delete state[URL_STATE_KEYS.BLOCK]
    }

    if (q) {
        state[URL_STATE_KEYS.Q] = q
    } else {
        delete state[URL_STATE_KEYS.Q]
    }

    return state
}

export function serializeStateKey({ doc, block, q }) {
    return `${doc || ''}|${block || ''}|${q || ''}`
}