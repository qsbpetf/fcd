import { parseMarkdown } from '../markdownParser'
import {
    buildDocumentIndex,
    collectDocumentPaths,
    extractSearchableEntries,
    searchDocuments,
} from '../searchIndex'

describe('searchIndex', () => {
    const navigationItems = [
        {
            label: 'System Overview',
            name: 'system-overview.md',
            path: 'system-overview.md',
        },
        {
            label: 'Architecture',
            name: 'root-1',
            items: [
                {
                    label: 'Architecture Overview',
                    name: 'architecture/architecture-overview.md',
                    path: 'architecture/architecture-overview.md',
                },
            ],
        },
    ]

    it('collects document paths from the navigation tree', () => {
        expect(collectDocumentPaths(navigationItems)).toEqual([
            { path: 'system-overview.md', label: 'System Overview' },
            { path: 'architecture/architecture-overview.md', label: 'Architecture Overview' },
        ])
    })

    it('extracts searchable entries from parsed markdown blocks', () => {
        const blocks = parseMarkdown('# Rubrik\n\nDet har ar **fetstil**.\n\n```apex\nCase c = new Case();\n```')

        expect(extractSearchableEntries(blocks)).toEqual([
            {
                blockKey: 'heading-0',
                anchorId: 'heading-0',
                text: 'Rubrik',
                type: 'heading',
                heading: 'Rubrik',
            },
            {
                blockKey: 'paragraph-1',
                anchorId: 'paragraph-1',
                text: 'Det har ar fetstil.',
                type: 'body',
                heading: 'Rubrik',
            },
            {
                blockKey: 'code-2',
                anchorId: 'code-2',
                text: 'Case c = new Case();',
                type: 'code',
                heading: 'Rubrik',
            },
        ])
    })

    it('indexes inline mermaid source for search', () => {
        const blocks = parseMarkdown('```mermaid\ngraph LR\n  A-->B\n```')

        expect(extractSearchableEntries(blocks)).toEqual([
            {
                blockKey: 'mermaid-0',
                anchorId: 'mermaid-0',
                text: 'graph LR\n  A-->B',
                type: 'code',
                heading: '',
            },
        ])
    })

    it('builds a document index from markdown content', () => {
        const index = buildDocumentIndex(
            'system-overview.md',
            'System Overview',
            '# System\n\nSmartform process.',
            parseMarkdown
        )

        expect(index.path).toBe('system-overview.md')
        expect(index.label).toBe('System Overview')
        expect(index.entries).toHaveLength(2)
    })

    it('ranks title matches higher than body text matches', () => {
        const index = [
            buildDocumentIndex('a.md', 'Smartform', '# Smartform\n\nAllmant innehall.', parseMarkdown),
            buildDocumentIndex('b.md', 'Case Management', '# Case\n\nSmartform process.', parseMarkdown),
        ]

        const results = searchDocuments(index, 'smartform')

        expect(results[0].label).toBe('Smartform')
        expect(results.some((result) => result.label === 'Case Management')).toBe(true)
    })

    it('filters search results to the current document when scopePath is set', () => {
        const index = [
            buildDocumentIndex('a.md', 'Document A', '# A\n\nGemensam term.', parseMarkdown),
            buildDocumentIndex('b.md', 'Document B', '# B\n\nGemensam term.', parseMarkdown),
        ]

        const results = searchDocuments(index, 'gemensam', { scopePath: 'b.md' })

        expect(results).toHaveLength(1)
        expect(results.every((result) => result.path === 'b.md')).toBe(true)
    })

    it('returns no results for queries shorter than two characters', () => {
        const index = [buildDocumentIndex('a.md', 'Document A', '# A\n\nText.', parseMarkdown)]

        expect(searchDocuments(index, 'a')).toEqual([])
    })
})
