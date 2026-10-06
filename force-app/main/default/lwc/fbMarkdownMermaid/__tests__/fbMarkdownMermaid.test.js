jest.mock(
    '@salesforce/resourceUrl/MermaidLib',
    () => ({
        default: '/resource/MermaidLib',
    }),
    { virtual: true }
)

jest.mock(
    'lightning/platformResourceLoader',
    () => ({
        loadScript: jest.fn(() => Promise.resolve()),
    }),
    { virtual: true }
)

import { createElement } from '@lwc/engine-dom'
import FbMarkdownMermaid from 'c/fbMarkdownMermaid'

const flushAsync = async () => {
    await Promise.resolve()
    await Promise.resolve()
    await new Promise((resolve) => setTimeout(resolve, 0))
}

describe('c-fb-markdown-mermaid', () => {
    beforeEach(() => {
        global.mermaid = {
            initialize: jest.fn(),
            render: jest.fn(() =>
                Promise.resolve({
                    svg: '<svg aria-label="mermaid-diagram"></svg>',
                })
            ),
        }
    })

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild)
        }
    })

    it('renders inline mermaid source as svg', async () => {
        const element = createElement('c-fb-markdown-mermaid', {
            is: FbMarkdownMermaid,
        })
        element.mermaidSource = 'graph LR\n  A-->B'

        document.body.appendChild(element)
        await flushAsync()
        await flushAsync()

        expect(global.mermaid.render).toHaveBeenCalled()
        expect(element.shadowRoot.querySelector('.mermaid-render-host').innerHTML).toContain('<svg')
    })

    it('fetches and renders .mmd sources from a url', async () => {
        global.fetch = jest.fn(() =>
            Promise.resolve({
                ok: true,
                text: () => Promise.resolve('sequenceDiagram\n  A->>B: Hej'),
            })
        )

        const element = createElement('c-fb-markdown-mermaid', {
            is: FbMarkdownMermaid,
        })
        element.mermaidSrc = '/resource/MarkdownDemo/docs/_images/example.mmd'
        element.alt = 'Exempel'

        document.body.appendChild(element)
        await flushAsync()
        await flushAsync()

        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/_images/example.mmd')
        expect(global.mermaid.render).toHaveBeenCalled()
        expect(element.shadowRoot.textContent).toContain('Exempel')
    })
})
