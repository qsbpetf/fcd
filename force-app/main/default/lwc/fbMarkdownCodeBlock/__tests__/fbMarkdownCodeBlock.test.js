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

import { createElement } from '@lwc/engine-dom'
import FbMarkdownCodeBlock from 'c/fbMarkdownCodeBlock'

const flushAsync = async () => {
    await Promise.resolve()
    await Promise.resolve()
    await new Promise((resolve) => setTimeout(resolve, 0))
}

describe('c-fb-markdown-code-block', () => {
    beforeEach(() => {
        global.hljs = {
            getLanguage: jest.fn((language) => ['json', 'xml', 'bash', 'apex', 'sql'].includes(language)),
            highlightElement: jest.fn(),
        }
    })

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild)
        }
    })

    it('applies syntax highlighting for supported languages', async () => {
        const element = createElement('c-fb-markdown-code-block', {
            is: FbMarkdownCodeBlock,
        })
        element.code = '{"enabled": true}'
        element.language = 'json'

        document.body.appendChild(element)
        await flushAsync()
        await flushAsync()

        expect(global.hljs.highlightElement).toHaveBeenCalled()
        expect(element.shadowRoot.textContent).toContain('JSON')
    })
})
