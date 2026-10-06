jest.mock(
    '@salesforce/resourceUrl/MermaidLib',
    () => ({
        default: '/resource/MermaidLib',
    }),
    { virtual: true }
)

jest.mock(
    '@salesforce/resourceUrl/HighlightJsLib',
    () => ({
        default: '/resource/HighlightJsLib',
    }),
    { virtual: true }
)

jest.mock(
    'lightning/platformResourceLoader',
    () => ({
        loadScript: jest.fn(() => Promise.resolve()),
        loadStyle: jest.fn(() => Promise.resolve()),
    }),
    { virtual: true }
)

import { resolveHighlightLanguage, highlightCodeElement } from '../highlightLoader'

describe('highlightLoader', () => {
    beforeEach(() => {
        global.hljs = {
            getLanguage: jest.fn((language) => ['json', 'xml', 'bash', 'apex', 'sql'].includes(language)),
            highlightElement: jest.fn(),
        }
    })

    it('maps common aliases to supported highlight.js languages', () => {
        expect(resolveHighlightLanguage('JSON')).toBe('json')
        expect(resolveHighlightLanguage('html')).toBe('xml')
        expect(resolveHighlightLanguage('shell')).toBe('bash')
        expect(resolveHighlightLanguage('apex')).toBe('apex')
    })

    it('highlights code when the language is supported', () => {
        const codeElement = document.createElement('code')

        expect(highlightCodeElement(codeElement, '{"a":1}', 'json')).toBe(true)
        expect(global.hljs.highlightElement).toHaveBeenCalledWith(codeElement)
        expect(codeElement.classList.contains('language-json')).toBe(true)
    })

    it('falls back to plain text for unsupported languages', () => {
        const codeElement = document.createElement('code')

        expect(highlightCodeElement(codeElement, 'plain text', 'unknown')).toBe(false)
        expect(codeElement.textContent).toBe('plain text')
    })
})
