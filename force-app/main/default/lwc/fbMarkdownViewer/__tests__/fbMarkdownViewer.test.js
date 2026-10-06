import { createElement } from '@lwc/engine-dom'
import { CurrentPageReference } from 'lightning/navigation'
import FbMarkdownViewer from 'c/fbMarkdownViewer'
import { markdownToHtml } from '../markdownParser'
import { URL_STATE_KEYS } from '../urlState'

jest.mock(
    '@salesforce/resourceUrl/MarkdownDemo',
    () => ({
        default: '/resource/MarkdownDemo',
    }),
    { virtual: true }
)

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

const flushPromises = async () => Promise.resolve()

const flushMicrotasks = async (times = 8) => {
    for (let index = 0; index < times; index += 1) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve()
    }
    await new Promise((resolve) => setTimeout(resolve, 0))
}

const setupMermaidMock = () => {
    global.mermaid = {
        initialize: jest.fn(),
        render: jest.fn(() =>
            Promise.resolve({
                svg: '<svg aria-label="mermaid-diagram"></svg>',
            })
        ),
    }
}

const setupHighlightMock = () => {
    global.hljs = {
        getLanguage: jest.fn((language) => ['json', 'xml', 'bash', 'apex', 'sql', 'java'].includes(language)),
        highlightElement: jest.fn(),
    }
}

const defaultPageReference = {
    type: 'standard__navItemPage',
    attributes: {
        apiName: 'Systemdokumentation',
    },
    state: {},
}

const emitPageReference = (state = {}) => {
    CurrentPageReference.emit({
        ...defaultPageReference,
        state,
    })
}

const nestedIndexFetchMock = {
    '/resource/MarkdownDemo/index.json': () =>
        Promise.resolve({
            ok: false,
            status: 404,
        }),
    '/resource/MarkdownDemo/docs/index.json': () =>
        Promise.resolve({
            ok: true,
            json: () =>
                Promise.resolve([
                    {
                        label: 'System Overview',
                        path: 'system-overview.md',
                    },
                    {
                        label: 'Architecture',
                        children: [
                            {
                                label: 'Architecture Overview',
                                path: 'architecture/architecture-overview.md',
                            },
                        ],
                    },
                ]),
        }),
    '/resource/MarkdownDemo/docs/system-overview.md': () =>
        Promise.resolve({
            ok: true,
            text: () => Promise.resolve('# System\n\nRoot document.'),
        }),
    '/resource/MarkdownDemo/docs/architecture/architecture-overview.md': () =>
        Promise.resolve({
            ok: true,
            text: () => Promise.resolve('# Arkitektur\n\nNested integrationer.'),
        }),
}

const createResourceFetchMock = (handlers) =>
    jest.fn((url) => {
        if (handlers[url]) {
            return handlers[url]()
        }

        return Promise.reject(new Error(`Unexpected fetch call: ${url}`))
    })

describe('c-fb-markdown-viewer', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild)
        }

        jest.clearAllMocks()
    })

    it('loads index.json and the first markdown document from the zip resource', async () => {
        global.fetch = createResourceFetchMock({
            '/resource/MarkdownDemo/index.json': () =>
                Promise.resolve({
                    ok: false,
                    status: 404,
                }),
            '/resource/MarkdownDemo/docs/index.json': () =>
                Promise.resolve({
                    ok: true,
                    json: () =>
                        Promise.resolve([
                            {
                                label: 'System Overview',
                                path: 'system-overview.md',
                            },
                        ]),
                }),
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Titel\n\nDet har ar **fetstil**.\n\n- Ett'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()

        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/index.json')
        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/index.json')
        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/system-overview.md')
        expect(element.shadowRoot.querySelector('.viewer-error')).toBeNull()
        expect(element.shadowRoot.querySelector('lightning-tree')).not.toBeNull()
    })

    it('shows an error when the zip resource cannot be loaded', async () => {
        global.fetch = jest.fn().mockRejectedValue(new Error('Network error'))

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()

        const error = element.shadowRoot.querySelector('.viewer-error')
        expect(error).not.toBeNull()
        expect(error.textContent).toContain('Network error')
    })

    it('loads a selected markdown document from the navigation tree', async () => {
        global.fetch = createResourceFetchMock({
            '/resource/MarkdownDemo/index.json': () =>
                Promise.resolve({
                    ok: false,
                    status: 404,
                }),
            '/resource/MarkdownDemo/docs/index.json': () =>
                Promise.resolve({
                    ok: true,
                    json: () =>
                        Promise.resolve([
                            {
                                label: 'System Overview',
                                path: 'system-overview.md',
                            },
                            {
                                label: 'Architecture',
                                children: [
                                    {
                                        label: 'Architecture Overview',
                                        path: 'architecture/architecture-overview.md',
                                    },
                                ],
                            },
                        ]),
                }),
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Start'),
                }),
            '/resource/MarkdownDemo/docs/architecture/architecture-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Arkitektur'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()

        const tree = element.shadowRoot.querySelector('lightning-tree')
        tree.dispatchEvent(
            new CustomEvent('select', {
                detail: {
                    name: 'architecture/architecture-overview.md',
                },
            })
        )

        await flushPromises()
        await flushPromises()

        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/architecture/architecture-overview.md')
    })

    it('intercepts internal markdown links and loads the target document', async () => {
        global.fetch = createResourceFetchMock({
            '/resource/MarkdownDemo/index.json': () =>
                Promise.resolve({
                    ok: false,
                    status: 404,
                }),
            '/resource/MarkdownDemo/docs/index.json': () =>
                Promise.resolve({
                    ok: true,
                    json: () =>
                        Promise.resolve([
                            {
                                label: 'README',
                                path: 'README.md',
                            },
                            {
                                label: 'System Overview',
                                path: 'system-overview.md',
                            },
                        ]),
                }),
            '/resource/MarkdownDemo/docs/README.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () =>
                        Promise.resolve(
                            '# Dokumentation\n\n[Systemoversikt](/Users/peterfriberg/IdeaProjects/Familjebostader/FB-PROD/docs/system-overview.md)'
                        ),
                }),
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Systemoversikt'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const markdownBody = element.shadowRoot.querySelector('.markdown-body')
        markdownBody.dispatchEvent(
            new CustomEvent('doclink', {
                detail: { docPath: 'system-overview.md' },
                bubbles: true,
                composed: true,
            })
        )

        await flushPromises()
        await flushPromises()

        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/system-overview.md')
    })

    it('renders a page-local image from the same static resource zip', async () => {
        global.fetch = createResourceFetchMock({
            '/resource/MarkdownDemo/index.json': () => Promise.resolve({ ok: false, status: 404 }),
            '/resource/MarkdownDemo/docs/index.json': () =>
                Promise.resolve({
                    ok: true,
                    json: () =>
                        Promise.resolve([
                            {
                                label: 'Arkitekturöversikt',
                                path: 'architecture/architecture-overview.md',
                            },
                        ]),
                }),
            '/resource/MarkdownDemo/docs/architecture/architecture-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Arkitektur\n\n![](_images/integration-landscape.png)'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const image = element.shadowRoot.querySelector('img')
        expect(image).not.toBeNull()
        expect(image.getAttribute('src')).toBe('/resource/MarkdownDemo/docs/architecture/_images/integration-landscape.png')
    })

    it('renders a shared image reference from the same static resource zip', async () => {
        global.fetch = createResourceFetchMock({
            '/resource/MarkdownDemo/index.json': () => Promise.resolve({ ok: false, status: 404 }),
            '/resource/MarkdownDemo/docs/index.json': () =>
                Promise.resolve({
                    ok: true,
                    json: () =>
                        Promise.resolve([
                            {
                                label: 'Integrationsöversikt',
                                path: 'integrations/integrations-overview.md',
                            },
                        ]),
                }),
            '/resource/MarkdownDemo/docs/integrations/integrations-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Integrationer\n\n![Legend](../_shared/images/legend-status-colors.png)'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const image = element.shadowRoot.querySelector('img')
        expect(image).not.toBeNull()
        expect(image.getAttribute('src')).toBe('/resource/MarkdownDemo/docs/_shared/images/legend-status-colors.png')
        expect(image.getAttribute('alt')).toBe('Legend')
    })

    it('converts a minimal markdown subset to safe html', () => {
        const html = markdownToHtml('# Titel\n\nEn [lank](https://example.com) och **fetstil**.\n\n- Punkt')

        expect(html).toContain('<h1>Titel</h1>')
        expect(html).toContain('<a href="https://example.com" target="_blank" rel="noopener noreferrer">lank</a>')
        expect(html).toContain('<strong>fetstil</strong>')
        expect(html).toContain('<ul><li>Punkt</li></ul>')
    })

    it('converts numbered markdown lists to ordered html lists', () => {
        const html = markdownToHtml('### Avancerad vag\n\n1. Smartform skickas in\n2. Salesforce skapar `Case`\n3. Salesforce skapar relaterade `Part__c`')

        expect(html).toContain('<h3>Avancerad vag</h3>')
        expect(html).toContain('<ol>')
        expect(html).toContain('<li>Smartform skickas in</li>')
        expect(html).toContain('<li>Salesforce skapar <code>Case</code></li>')
        expect(html).toContain('<li>Salesforce skapar relaterade <code>Part__c</code></li>')
        expect(html).toContain('</ol>')
    })

    it('converts nested unordered markdown lists to nested html lists', () => {
        const html = markdownToHtml(
            'Fakta:\n- label: MainFlow(new) - Create Case from Smartform\n- status: Active\n- skiljer mellan minst tva huvudlagen:\n  - Dialog Values Complete\n  - Dialog Signed'
        )

        expect(html).toContain('<ul>')
        expect(html).toContain('<li>skiljer mellan minst tva huvudlagen:<ul>')
        expect(html).toContain('<li>Dialog Values Complete</li>')
        expect(html).toContain('<li>Dialog Signed</li>')
    })

    it('keeps ordered numbering when an unordered sublist exists inside an ordered list', () => {
        const html = markdownToHtml(
            '### Steg\n\n1. Avy oppnar en publik Salesforce site i en iframe.\n2. Den publika siten visar en LWC.\n3. LWC anropar Apex for att:\n   - verifiera JWT\n   - hamta tenant-/kontraktsdata fran Salesforce\n4. Den skapade Smartformen returneras och visas for anvandaren.'
        )

        expect(html).toContain('<ol>')
        expect(html).toContain('<li>LWC anropar Apex for att:<ul>')
        expect(html).toContain('<li>verifiera JWT</li>')
        expect(html).toContain('<li>hamta tenant-/kontraktsdata fran Salesforce</li>')
        expect(html).toContain('<li>Den skapade Smartformen returneras och visas for anvandaren.</li>')
    })

    it('builds a search index in the background and shows matching results', async () => {
        jest.useFakeTimers()

        global.fetch = createResourceFetchMock({
            '/resource/MarkdownDemo/index.json': () =>
                Promise.resolve({
                    ok: false,
                    status: 404,
                }),
            '/resource/MarkdownDemo/docs/index.json': () =>
                Promise.resolve({
                    ok: true,
                    json: () =>
                        Promise.resolve([
                            {
                                label: 'System Overview',
                                path: 'system-overview.md',
                            },
                            {
                                label: 'Architecture Overview',
                                path: 'architecture/architecture-overview.md',
                            },
                        ]),
                }),
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# System\n\nSmartform startar processen.'),
                }),
            '/resource/MarkdownDemo/docs/architecture/architecture-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Arkitektur\n\nIntegrationer och flows.'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const searchInput = element.shadowRoot.querySelector('lightning-input')
        searchInput.value = 'smartform'
        searchInput.dispatchEvent(new CustomEvent('change', { detail: { value: 'smartform' } }))

        jest.advanceTimersByTime(300)
        await flushPromises()
        await flushPromises()

        const results = element.shadowRoot.querySelectorAll('.search-result-item')
        expect(results.length).toBeGreaterThan(0)
        expect(element.shadowRoot.textContent).toContain('Smartform startar processen.')

        jest.useRealTimers()
    })

    it('navigates to a selected search result and renders highlighted text', async () => {
        jest.useFakeTimers()

        global.fetch = createResourceFetchMock({
            '/resource/MarkdownDemo/index.json': () =>
                Promise.resolve({
                    ok: false,
                    status: 404,
                }),
            '/resource/MarkdownDemo/docs/index.json': () =>
                Promise.resolve({
                    ok: true,
                    json: () =>
                        Promise.resolve([
                            {
                                label: 'System Overview',
                                path: 'system-overview.md',
                            },
                            {
                                label: 'Architecture Overview',
                                path: 'architecture/architecture-overview.md',
                            },
                        ]),
                }),
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# System\n\nSmartform startar processen.'),
                }),
            '/resource/MarkdownDemo/docs/architecture/architecture-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Arkitektur\n\nIntegrationer och flows.'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const searchInput = element.shadowRoot.querySelector('lightning-input')
        searchInput.value = 'integrationer'
        searchInput.dispatchEvent(new CustomEvent('change', { detail: { value: 'integrationer' } }))

        jest.advanceTimersByTime(300)
        await flushPromises()
        await flushPromises()

        const resultButton = element.shadowRoot.querySelector('.search-result-button')
        resultButton.click()

        await flushPromises()
        await flushPromises()
        await flushPromises()

        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/architecture/architecture-overview.md')
        expect(element.shadowRoot.querySelector('[data-block-key="paragraph-1"]')).not.toBeNull()

        const inlineComponent = element.shadowRoot.querySelector('[data-block-key="paragraph-1"] c-fb-markdown-inline')
        expect(inlineComponent.shadowRoot.querySelector('mark')).not.toBeNull()

        jest.useRealTimers()
    })

    it('limits search results to the current document when scope is set', async () => {
        jest.useFakeTimers()

        global.fetch = createResourceFetchMock({
            '/resource/MarkdownDemo/index.json': () =>
                Promise.resolve({
                    ok: false,
                    status: 404,
                }),
            '/resource/MarkdownDemo/docs/index.json': () =>
                Promise.resolve({
                    ok: true,
                    json: () =>
                        Promise.resolve([
                            {
                                label: 'System Overview',
                                path: 'system-overview.md',
                            },
                            {
                                label: 'Architecture Overview',
                                path: 'architecture/architecture-overview.md',
                            },
                        ]),
                }),
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# System\n\nGemensam term i systemet.'),
                }),
            '/resource/MarkdownDemo/docs/architecture/architecture-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Arkitektur\n\nGemensam term i arkitekturen.'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const scopeButtons = element.shadowRoot.querySelectorAll('lightning-button')
        scopeButtons[1].click()

        const searchInput = element.shadowRoot.querySelector('lightning-input')
        searchInput.value = 'gemensam'
        searchInput.dispatchEvent(new CustomEvent('change', { detail: { value: 'gemensam' } }))

        jest.advanceTimersByTime(300)
        await flushPromises()
        await flushPromises()

        const resultLabels = [...element.shadowRoot.querySelectorAll('.search-result-label')].map(
            (node) => node.textContent
        )

        expect(resultLabels.every((label) => label === 'System Overview')).toBe(true)
        expect(element.shadowRoot.textContent).not.toContain('Gemensam term i arkitekturen.')

        jest.useRealTimers()
    })

    it('expands the sidebar tree when navigating to a nested search result', async () => {
        jest.useFakeTimers()

        global.fetch = createResourceFetchMock({
            '/resource/MarkdownDemo/index.json': () =>
                Promise.resolve({
                    ok: false,
                    status: 404,
                }),
            '/resource/MarkdownDemo/docs/index.json': () =>
                Promise.resolve({
                    ok: true,
                    json: () =>
                        Promise.resolve([
                            {
                                label: 'System Overview',
                                path: 'system-overview.md',
                            },
                            {
                                label: 'Architecture',
                                children: [
                                    {
                                        label: 'Architecture Overview',
                                        path: 'architecture/architecture-overview.md',
                                    },
                                ],
                            },
                        ]),
                }),
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# System\n\nRoot document.'),
                }),
            '/resource/MarkdownDemo/docs/architecture/architecture-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Arkitektur\n\nNested integrationer.'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const searchInput = element.shadowRoot.querySelector('lightning-input')
        searchInput.value = 'integrationer'
        searchInput.dispatchEvent(new CustomEvent('change', { detail: { value: 'integrationer' } }))

        jest.advanceTimersByTime(300)
        await flushPromises()
        await flushPromises()

        const resultButton = element.shadowRoot.querySelector('.search-result-button')
        resultButton.click()

        await flushPromises()
        await flushPromises()
        await flushPromises()

        const tree = element.shadowRoot.querySelector('lightning-tree')
        const architectureBranch = tree.items.find((item) => item.label === 'Architecture')

        expect(architectureBranch.expanded).toBe(true)
        expect(tree.selectedItem).toBe('architecture/architecture-overview.md')

        jest.useRealTimers()
    })

    it('loads a deep-linked document from page reference state instead of the first document', async () => {
        global.fetch = createResourceFetchMock(nestedIndexFetchMock)

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference({
            [URL_STATE_KEYS.DOC]: 'architecture/architecture-overview.md',
        })

        await flushPromises()
        await flushPromises()
        await flushPromises()

        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/architecture/architecture-overview.md')
        expect(element.shadowRoot.querySelector('.viewer-error')).toBeNull()
        expect(element.shadowRoot.querySelector('lightning-tree').selectedItem).toBe(
            'architecture/architecture-overview.md'
        )
    })

    it('reacts to page reference changes for browser navigation', async () => {
        global.fetch = createResourceFetchMock(nestedIndexFetchMock)

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushPromises()
        await flushPromises()
        await flushPromises()

        emitPageReference({
            [URL_STATE_KEYS.DOC]: 'architecture/architecture-overview.md',
            [URL_STATE_KEYS.BLOCK]: 'paragraph-1',
            [URL_STATE_KEYS.Q]: 'integrationer',
        })

        await flushPromises()
        await flushPromises()
        await flushPromises()

        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/architecture/architecture-overview.md')
        expect(element.shadowRoot.querySelector('lightning-tree').selectedItem).toBe(
            'architecture/architecture-overview.md'
        )
        expect(element.shadowRoot.querySelector('[data-block-key="paragraph-1"]')).not.toBeNull()

        const inlineComponent = element.shadowRoot.querySelector('[data-block-key="paragraph-1"] c-fb-markdown-inline')
        expect(inlineComponent.shadowRoot.querySelector('mark')).not.toBeNull()
    })

    it('shows an error and falls back when the deep-linked document is missing from navigation', async () => {
        global.fetch = createResourceFetchMock(nestedIndexFetchMock)

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference({
            [URL_STATE_KEYS.DOC]: 'missing/document.md',
        })

        await flushPromises()
        await flushPromises()
        await flushPromises()

        const error = element.shadowRoot.querySelector('.viewer-error')
        expect(error).not.toBeNull()
        expect(error.textContent).toContain('is not in the navigation')
        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/system-overview.md')
    })

    it('shows a table of contents for documents with multiple H2/H3 headings', async () => {
        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () =>
                        Promise.resolve(
                            '# System\n\n## Syfte\n\nIntro.\n\n## Teknisk modell\n\nDetaljer.\n\n### Underavsnitt\n\nMer.'
                        ),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const toc = element.shadowRoot.querySelector('.docs-toc')
        expect(toc).not.toBeNull()
        expect(element.shadowRoot.querySelectorAll('.toc-button')).toHaveLength(4)
        expect(toc.textContent).toContain('System')
        expect(toc.textContent).toContain('Syfte')
        expect(toc.textContent).toContain('Underavsnitt')
    })

    it('hides the table of contents when the document has fewer than two headings', async () => {
        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# System\n\nText utan fler rubriker.'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushPromises()
        await flushPromises()
        await flushPromises()

        expect(element.shadowRoot.querySelector('.docs-toc')).toBeNull()
    })

    it('scrolls to a section and marks it active when a TOC entry is clicked', async () => {
        const scrollIntoViewMock = jest.fn()
        Element.prototype.scrollIntoView = scrollIntoViewMock
        const originalRequestAnimationFrame = global.requestAnimationFrame
        global.requestAnimationFrame = (callback) => {
            callback()
            return 0
        }

        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () =>
                        Promise.resolve('# System\n\n## Syfte\n\nIntro.\n\n## Teknisk modell\n\nDetaljer.'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const tocButtons = [...element.shadowRoot.querySelectorAll('.toc-button')]
        const technicalButton = tocButtons.find((button) => button.textContent === 'Teknisk modell')
        technicalButton.click()

        await flushPromises()
        await flushPromises()

        expect(scrollIntoViewMock).toHaveBeenCalled()
        expect(technicalButton.classList.contains('toc-button-active')).toBe(true)

        global.requestAnimationFrame = originalRequestAnimationFrame
    })

    it('keeps the clicked H2 active when an H3 below is closer to the viewport center', async () => {
        const scrollIntoViewMock = jest.fn()
        Element.prototype.scrollIntoView = scrollIntoViewMock
        const originalRequestAnimationFrame = global.requestAnimationFrame
        global.requestAnimationFrame = (callback) => {
            callback()
            return 0
        }

        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () =>
                        Promise.resolve(
                            '# Part\n\n## Hur Part__c skapas\n\nIntro.\n\n### Via Smartformflöden\n\nDetaljer.'
                        ),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const tocButtons = [...element.shadowRoot.querySelectorAll('.toc-button')]
        const h2Button = tocButtons.find((button) => button.textContent === 'Hur Part__c skapas')
        const h3Button = tocButtons.find((button) => button.textContent === 'Via Smartformflöden')
        const h2BlockKey = h2Button.dataset.blockKey
        const h3BlockKey = h3Button.dataset.blockKey

        const sections = [...element.shadowRoot.querySelectorAll('[data-block-key]')]
        const rectByKey = {
            [h2BlockKey]: {
                top: 80,
                bottom: 0,
                left: 0,
                right: 0,
                width: 0,
                height: 0,
            },
            [h3BlockKey]: {
                top: 200,
                bottom: 0,
                left: 0,
                right: 0,
                width: 0,
                height: 0,
            },
        }

        sections.forEach((section) => {
            const rect = rectByKey[section.dataset.blockKey]

            if (rect) {
                section.getBoundingClientRect = jest.fn(() => rect)
            }
        })

        h2Button.click()
        await flushPromises()

        expect(scrollIntoViewMock).toHaveBeenCalled()
        expect(h2Button.classList.contains('toc-button-active')).toBe(true)
        expect(h3Button.classList.contains('toc-button-active')).toBe(false)

        window.dispatchEvent(new Event('scroll'))
        await flushPromises()

        expect(h2Button.classList.contains('toc-button-active')).toBe(true)
        expect(h3Button.classList.contains('toc-button-active')).toBe(false)

        global.requestAnimationFrame = originalRequestAnimationFrame
    })

    it('keeps the clicked heading active when it lands slightly below the activation offset', async () => {
        const scrollIntoViewMock = jest.fn()
        Element.prototype.scrollIntoView = scrollIntoViewMock
        const originalRequestAnimationFrame = global.requestAnimationFrame
        global.requestAnimationFrame = (callback) => {
            callback()
            return 0
        }

        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () =>
                        Promise.resolve(
                            '# Part\n\n## Forsta avsnitt\n\nIntro.\n\n## Andra avsnitt\n\nMer text.'
                        ),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const tocButtons = [...element.shadowRoot.querySelectorAll('.toc-button')]
        const firstButton = tocButtons.find((button) => button.textContent === 'Forsta avsnitt')
        const secondButton = tocButtons.find((button) => button.textContent === 'Andra avsnitt')
        const firstBlockKey = firstButton.dataset.blockKey
        const secondBlockKey = secondButton.dataset.blockKey

        const sections = [...element.shadowRoot.querySelectorAll('[data-block-key]')]
        const rectByKey = {
            [firstBlockKey]: {
                top: -320,
                bottom: 0,
                left: 0,
                right: 0,
                width: 0,
                height: 0,
            },
            [secondBlockKey]: {
                top: 140,
                bottom: 0,
                left: 0,
                right: 0,
                width: 0,
                height: 0,
            },
        }

        sections.forEach((section) => {
            const rect = rectByKey[section.dataset.blockKey]

            if (rect) {
                section.getBoundingClientRect = jest.fn(() => rect)
            }
        })

        element.tocScrollLockKey = null
        element.tocScrollLockUntil = 0
        secondButton.click()
        await flushPromises()

        window.dispatchEvent(new Event('scroll'))
        await flushPromises()

        expect(secondButton.classList.contains('toc-button-active')).toBe(true)
        expect(firstButton.classList.contains('toc-button-active')).toBe(false)

        global.requestAnimationFrame = originalRequestAnimationFrame
    })

    it('marks the deep-linked block as active in the table of contents', async () => {
        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/architecture/architecture-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () =>
                        Promise.resolve(
                            '# Arkitektur\n\n## Oversikt\n\nIntro.\n\n## Integrationer\n\nDetaljer om integrationer.'
                        ),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference({
            [URL_STATE_KEYS.DOC]: 'architecture/architecture-overview.md',
            [URL_STATE_KEYS.BLOCK]: 'heading-3',
        })

        await flushPromises()
        await flushPromises()
        await flushPromises()

        const activeButton = element.shadowRoot.querySelector('.toc-button-active')
        expect(activeButton).not.toBeNull()
        expect(activeButton.textContent).toBe('Integrationer')
    })

    it('renders fenced mermaid blocks as svg diagrams', async () => {
        setupMermaidMock()

        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () =>
                        Promise.resolve('# Diagram\n\n```mermaid\nsequenceDiagram\n  A->>B: Hej\n```'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushMicrotasks()

        const mermaidBlock = element.shadowRoot.querySelector('c-fb-markdown-mermaid')
        expect(mermaidBlock).not.toBeNull()
        expect(mermaidBlock.shadowRoot.querySelector('.mermaid-render-host')).not.toBeNull()
    })

    it('loads .mmd diagram sources referenced as images', async () => {
        setupMermaidMock()

        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Diagram\n\n![Tele2 CTI](_images/tele2-cti-sequence.mmd)'),
                }),
            '/resource/MarkdownDemo/docs/_images/tele2-cti-sequence.mmd': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('sequenceDiagram\n  Client->>Server: Call'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushMicrotasks()

        expect(global.fetch).toHaveBeenCalledWith('/resource/MarkdownDemo/docs/_images/tele2-cti-sequence.mmd')

        const mermaidBlock = element.shadowRoot.querySelector('c-fb-markdown-mermaid')
        expect(mermaidBlock).not.toBeNull()
        expect(mermaidBlock.shadowRoot.textContent).toContain('Tele2 CTI')
    })

    it('renders code blocks with language labels and a copy button', async () => {
        setupHighlightMock()

        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Kod\n\n```json\n{"enabled": true}\n```'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushMicrotasks()

        const codeBlock = element.shadowRoot.querySelector('c-fb-markdown-code-block')
        expect(codeBlock).not.toBeNull()
        expect(codeBlock.shadowRoot.textContent).toContain('JSON')
        expect(codeBlock.shadowRoot.querySelector('.code-copy-button')).not.toBeNull()
    })

    it('copies fenced code when the copy button is clicked', async () => {
        setupHighlightMock()

        const writeTextMock = jest.fn().mockResolvedValue(undefined)
        Object.assign(navigator, {
            clipboard: {
                writeText: writeTextMock,
            },
        })
        Object.defineProperty(window, 'isSecureContext', {
            configurable: true,
            value: true,
        })

        global.fetch = createResourceFetchMock({
            ...nestedIndexFetchMock,
            '/resource/MarkdownDemo/docs/system-overview.md': () =>
                Promise.resolve({
                    ok: true,
                    text: () => Promise.resolve('# Kod\n\n```apex\nCase c = new Case();\n```'),
                }),
        })

        const element = createElement('c-fb-markdown-viewer', {
            is: FbMarkdownViewer,
        })

        document.body.appendChild(element)
        emitPageReference()
        await flushPromises()
        await flushPromises()
        await flushPromises()

        const codeBlock = element.shadowRoot.querySelector('c-fb-markdown-code-block')
        codeBlock.shadowRoot.querySelector('.code-copy-button').click()

        await flushPromises()

        expect(writeTextMock).toHaveBeenCalledWith('Case c = new Case();')
    })
})
