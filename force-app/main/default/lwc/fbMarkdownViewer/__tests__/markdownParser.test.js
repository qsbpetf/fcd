import { parseMarkdown } from '../markdownParser'

describe('markdownParser', () => {
    it('captures language on fenced code blocks', () => {
        const blocks = parseMarkdown('```apex\nCase c = new Case();\n```')

        expect(blocks).toHaveLength(1)
        expect(blocks[0]).toMatchObject({
            isCodeBlock: true,
            language: 'apex',
            code: 'Case c = new Case();',
        })
    })

    it('parses plain fenced blocks without a language tag', () => {
        const blocks = parseMarkdown('```\nplain text\n```')

        expect(blocks[0]).toMatchObject({
            isCodeBlock: true,
            language: null,
            code: 'plain text',
        })
    })

    it('gives headings the same anchor id as a markdown hash link', () => {
        const blocks = parseMarkdown('## When an Opportunity update sends a webhook')

        expect(blocks[0].anchorId).toBe('when-an-opportunity-update-sends-a-webhook')
    })

    it('keeps a double hyphen when heading punctuation is removed', () => {
        const blocks = parseMarkdown('## Commerce API invoice line → Opportunity Product')

        expect(blocks[0].anchorId).toBe('commerce-api-invoice-line--opportunity-product')
    })

    it('normalizes fenced language tags to lowercase', () => {
        const blocks = parseMarkdown('```JSON\n{"a":1}\n```')

        expect(blocks[0].language).toBe('json')
    })

    it('creates mermaid blocks from fenced mermaid blocks', () => {
        const blocks = parseMarkdown('```mermaid\ngraph LR\n  A-->B\n```')

        expect(blocks).toHaveLength(1)
        expect(blocks[0]).toMatchObject({
            isMermaidBlock: true,
            mermaidSource: 'graph LR\n  A-->B',
        })
        expect(blocks[0].isCodeBlock).toBeUndefined()
    })

    it('creates mermaid blocks from .mmd image references', () => {
        const blocks = parseMarkdown('![Sekvensdiagram](_images/tele2-cti-sequence.mmd)', {
            resolveUrl: (url) => `/resource/MarkdownDemo/docs/${url}`,
        })

        expect(blocks).toHaveLength(1)
        expect(blocks[0]).toMatchObject({
            isMermaidBlock: true,
            mermaidSrc: '/resource/MarkdownDemo/docs/_images/tele2-cti-sequence.mmd',
            alt: 'Sekvensdiagram',
        })
        expect(blocks[0].isImage).toBeUndefined()
    })

    it('still renders regular images that are not .mmd files', () => {
        const blocks = parseMarkdown('![Arkitektur](_images/overview.png)', {
            resolveUrl: (url) => `/resource/MarkdownDemo/docs/${url}`,
        })

        expect(blocks[0]).toMatchObject({
            isImage: true,
            src: '/resource/MarkdownDemo/docs/_images/overview.png',
            alt: 'Arkitektur',
        })
    })
})
