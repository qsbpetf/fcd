import HIGHLIGHT_LIB from '@salesforce/resourceUrl/HighlightJsLib'
import { loadScript, loadStyle } from 'lightning/platformResourceLoader'

let loadPromise

const LANGUAGE_ALIASES = {
    apex: 'apex',
    java: 'java',
    json: 'json',
    xml: 'xml',
    html: 'xml',
    bash: 'bash',
    shell: 'bash',
    sh: 'bash',
    sql: 'sql',
}

export function resolveHighlightLanguage(language = '') {
    const normalized = language.trim().toLowerCase()

    if (!normalized) {
        return null
    }

    return LANGUAGE_ALIASES[normalized] || normalized
}

export function ensureHighlightLoaded(component) {
    if (!loadPromise) {
        loadPromise = Promise.all([
            loadScript(window, `${HIGHLIGHT_LIB}/highlight.min.js`),
            loadStyle(component, `${HIGHLIGHT_LIB}/github.min.css`),
        ])
    }

    return loadPromise
}

export function highlightCodeElement(codeElement, code, language) {
    if (!codeElement || !window.hljs) {
        return false
    }

    const resolvedLanguage = resolveHighlightLanguage(language)
    codeElement.removeAttribute('data-highlighted')
    codeElement.className = 'code-block-code'
    codeElement.textContent = code || ''

    if (resolvedLanguage && window.hljs.getLanguage(resolvedLanguage)) {
        codeElement.classList.add(`language-${resolvedLanguage}`)
        window.hljs.highlightElement(codeElement)
        return true
    }

    return false
}