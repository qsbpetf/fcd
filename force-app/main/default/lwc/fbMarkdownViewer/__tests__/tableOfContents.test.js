import { parseMarkdown } from '../markdownParser'
import {
    buildTableOfContentsView,
    extractTableOfContents,
    resolveActiveTocBlockKey,
} from '../tableOfContents'

describe('tableOfContents', () => {
    it('extracts H1, H2 and H3 headings with block keys and labels', () => {
        const blocks = parseMarkdown('# Titel\n\n## Syfte\n\nText.\n\n### Detalj\n\nMer text.')

        expect(extractTableOfContents(blocks)).toEqual([
            {
                key: 'heading-0',
                blockKey: 'heading-0',
                anchorId: 'heading-0',
                label: 'Titel',
                level: 1,
            },
            {
                key: 'heading-1',
                blockKey: 'heading-1',
                anchorId: 'heading-1',
                label: 'Syfte',
                level: 2,
            },
            {
                key: 'heading-3',
                blockKey: 'heading-3',
                anchorId: 'heading-3',
                label: 'Detalj',
                level: 3,
            },
        ])
    })

    it('returns only the document title when no subheadings exist', () => {
        const blocks = parseMarkdown('# Endast titel\n\nStycke utan rubrik.')

        expect(extractTableOfContents(blocks)).toEqual([
            {
                key: 'heading-0',
                blockKey: 'heading-0',
                anchorId: 'heading-0',
                label: 'Endast titel',
                level: 1,
            },
        ])
    })

    it('prefers the H2 at the top of the viewport over an H3 further down', () => {
        const entries = [
            { blockKey: 'heading-1' },
            { blockKey: 'heading-3' },
        ]
        const tops = {
            'heading-1': 80,
            'heading-3': 200,
        }

        expect(resolveActiveTocBlockKey(entries, (blockKey) => tops[blockKey])).toBe('heading-1')
    })

    it('selects a clicked heading that lands slightly below the activation offset', () => {
        const entries = [
            { blockKey: 'heading-1' },
            { blockKey: 'heading-3' },
        ]
        const tops = {
            'heading-1': -300,
            'heading-3': 140,
        }

        expect(resolveActiveTocBlockKey(entries, (blockKey) => tops[blockKey])).toBe('heading-3')
    })

    it('activates an H3 when it is the heading nearest the top of the viewport', () => {
        const entries = [
            { blockKey: 'heading-1' },
            { blockKey: 'heading-3' },
        ]
        const tops = {
            'heading-1': -120,
            'heading-3': 90,
        }

        expect(resolveActiveTocBlockKey(entries, (blockKey) => tops[blockKey])).toBe('heading-3')
    })

    it('builds view classes with active state for the selected heading', () => {
        const entries = [
            {
                key: 'heading-1',
                blockKey: 'heading-1',
                anchorId: 'heading-1',
                label: 'Syfte',
                level: 2,
            },
        ]

        expect(buildTableOfContentsView(entries, 'heading-1')[0]).toEqual(
            expect.objectContaining({
                itemClass: 'toc-item toc-level-2 toc-item-active',
                buttonClass: 'toc-button toc-button-active',
            })
        )
    })
})
