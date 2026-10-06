import { extractListText, extractTextFromParts } from './markdownText'

const MAX_RESULTS = 20
const MIN_QUERY_LENGTH = 2
const SNIPPET_CONTEXT = 60

export function collectDocumentPaths(navigationItems = []) {
    const paths = []

    const walk = (items) => {
        items.forEach((item) => {
            if (item.path) {
                paths.push({ path: item.path, label: item.label })
                return
            }

            if (item.items?.length) {
                walk(item.items)
            }
        })
    }

    walk(navigationItems)
    return paths
}

export function extractSearchableEntries(blocks = []) {
    const entries = []
    let currentHeading = ''

    blocks.forEach((block) => {
        if (block.isImage) {
            return
        }

        let text = ''
        let type = 'body'

        if (block.isHeading1 || block.isHeading2 || block.isHeading3) {
            text = extractTextFromParts(block.parts)
            currentHeading = text
            type = 'heading'
        } else if (block.isMermaidBlock) {
            text = block.mermaidSource || block.alt || ''
            type = 'code'
        } else if (block.isCodeBlock) {
            text = block.code
            type = 'code'
        } else if (block.isList) {
            text = extractListText(block.items)
        } else if (block.isBlockquote) {
            text = block.lines.map((line) => extractTextFromParts(line.parts)).join(' ')
        } else if (block.isTable) {
            text = [
                ...block.headers.map((header) => extractTextFromParts(header.parts)),
                ...block.rows.flatMap((row) => row.cells.map((cell) => extractTextFromParts(cell.parts))),
            ].join(' ')
        } else if (block.lines) {
            text = block.lines.map((line) => extractTextFromParts(line.parts)).join(' ')
        }

        if (!text.trim()) {
            return
        }

        entries.push({
            blockKey: block.key,
            anchorId: block.anchorId || block.key,
            text: text.trim(),
            type,
            heading: currentHeading,
        })
    })

    return entries
}

export function buildDocumentIndex(path, label, markdown, parseMarkdownFn) {
    const blocks = parseMarkdownFn(markdown)

    return {
        path,
        label,
        entries: extractSearchableEntries(blocks),
    }
}

function createSnippet(text, query, matchIndex) {
    const start = Math.max(0, matchIndex - SNIPPET_CONTEXT)
    const end = Math.min(text.length, matchIndex + query.length + SNIPPET_CONTEXT)
    let snippet = text.slice(start, end)

    if (start > 0) {
        snippet = `...${snippet}`
    }

    if (end < text.length) {
        snippet = `${snippet}...`
    }

    return snippet
}

export function searchDocuments(index = [], query = '', options = {}) {
    const normalizedQuery = query.trim().toLowerCase()

    if (normalizedQuery.length < MIN_QUERY_LENGTH) {
        return []
    }

    const { scopePath, maxResults = MAX_RESULTS } = options
    const filteredIndex = scopePath ? index.filter((document) => document.path === scopePath) : index
    const results = []

    filteredIndex.forEach((document) => {
        const labelLower = document.label.toLowerCase()

        if (labelLower.includes(normalizedQuery)) {
            results.push({
                path: document.path,
                label: document.label,
                blockKey: document.entries[0]?.blockKey || null,
                sectionHeading: null,
                snippet: document.label,
                score: 100,
                resultKey: `${document.path}-title`,
            })
        }

        document.entries.forEach((entry) => {
            const textLower = entry.text.toLowerCase()
            const matchIndex = textLower.indexOf(normalizedQuery)

            if (matchIndex === -1) {
                return
            }

            let score = entry.type === 'heading' ? 80 : 50

            if (entry.heading && entry.heading.toLowerCase().includes(normalizedQuery)) {
                score += 10
            }

            results.push({
                path: document.path,
                label: document.label,
                blockKey: entry.blockKey,
                sectionHeading: entry.heading && entry.heading !== document.label ? entry.heading : null,
                snippet: createSnippet(entry.text, normalizedQuery, matchIndex),
                score,
                resultKey: `${document.path}-${entry.blockKey}-${matchIndex}`,
            })
        })
    })

    return results
        .sort((left, right) => right.score - left.score || left.label.localeCompare(right.label, 'sv'))
        .slice(0, maxResults)
}