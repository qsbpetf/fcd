import { extractTextFromParts } from './markdownText'

function sanitizeUrl(url) {
    if (/^(https?:|mailto:|tel:|\/)/i.test(url)) {
        return url
    }

    return '#'
}

function createTextPart(text, index) {
    return {
        key: `text-${index}`,
        text,
        isText: true,
    }
}

function buildInlineParts(text, resolveLink = (url) => ({ url: sanitizeUrl(url) })) {
    const parts = []
    const pattern = /\[([^\]]+)\]\(([^)]+)\)|\*\*([^*]+)\*\*|\*([^*]+)\*|`([^`]+)`/g
    let lastIndex = 0
    let match

    while ((match = pattern.exec(text)) !== null) {
        if (match.index > lastIndex) {
            parts.push(createTextPart(text.slice(lastIndex, match.index), parts.length))
        }

        if (match[1] && match[2]) {
            const resolvedLink = resolveLink(match[2])
            parts.push({
                key: `link-${parts.length}`,
                isLink: true,
                label: match[1],
                url: resolvedLink.url,
                docPath: resolvedLink.docPath,
                anchor: resolvedLink.anchor,
                isInternalDoc: Boolean(resolvedLink.docPath),
            })
        } else if (match[3]) {
            parts.push({
                key: `strong-${parts.length}`,
                isStrong: true,
                text: match[3],
            })
        } else if (match[4]) {
            parts.push({
                key: `em-${parts.length}`,
                isEmphasis: true,
                text: match[4],
            })
        } else if (match[5]) {
            parts.push({
                key: `code-${parts.length}`,
                isCode: true,
                text: match[5],
            })
        }

        lastIndex = pattern.lastIndex
    }

    if (lastIndex < text.length) {
        parts.push(createTextPart(text.slice(lastIndex), parts.length))
    }

    return parts.length ? parts : [createTextPart(text, 0)]
}

function createParagraphBlock(lines, index, resolveLink) {
    return {
        key: `paragraph-${index}`,
        isParagraph: true,
        lines: lines.map((line, lineIndex) => ({
            key: `paragraph-line-${index}-${lineIndex}`,
            parts: buildInlineParts(line, resolveLink),
        })),
    }
}

function createHeadingBlock(level, text, index, resolveLink) {
    return {
        key: `heading-${index}`,
        level,
        isHeading1: level === 1,
        isHeading2: level === 2,
        isHeading3: level === 3,
        parts: buildInlineParts(text, resolveLink),
    }
}

function buildNestedListItems(items, resolveLink, keyPrefix) {
    const rootItems = []
    const stack = [{ indent: -1, children: rootItems }]

    items.forEach((item, itemIndex) => {
        while (stack.length > 1 && stack[stack.length - 1].indent >= item.indent) {
            stack.pop()
        }

        const listItem = {
            key: `${keyPrefix}-item-${itemIndex}`,
            parts: buildInlineParts(item.text, resolveLink),
            children: [],
            childrenOrdered: false,
        }

        stack[stack.length - 1].children.push(listItem)
        const parentChildren = stack[stack.length - 1].children
        if (parentChildren.length === 1) {
            const parentItem = stack[stack.length - 1].parentItem
            if (parentItem) {
                parentItem.childrenOrdered = item.ordered
            }
        }

        stack.push({
            indent: item.indent,
            children: listItem.children,
            parentItem: listItem,
        })
    })

    return rootItems
}

function createListBlock(items, index, resolveLink) {
    return {
        key: `list-${index}`,
        isList: true,
        ordered: items[0]?.ordered || false,
        items: buildNestedListItems(items, resolveLink, `list-${index}`),
    }
}

function createBlockquoteBlock(lines, index, resolveLink) {
    return {
        key: `blockquote-${index}`,
        isBlockquote: true,
        lines: lines.map((line, lineIndex) => ({
            key: `blockquote-line-${index}-${lineIndex}`,
            parts: buildInlineParts(line, resolveLink),
        })),
    }
}

const MERMAID_LANGUAGE = 'mermaid'

function normalizeFenceLanguage(raw = '') {
    return raw.trim().toLowerCase()
}

function isMermaidReference(url = '') {
    return url.trim().toLowerCase().endsWith('.mmd')
}

function createCodeBlock(lines, index, language = '') {
    return {
        key: `code-${index}`,
        isCodeBlock: true,
        code: lines.join('\n'),
        language: language || null,
    }
}

function createMermaidBlock(index, { mermaidSource = null, mermaidSrc = null, alt = '' } = {}) {
    return {
        key: `mermaid-${index}`,
        isMermaidBlock: true,
        mermaidSource,
        mermaidSrc,
        alt,
    }
}

function createTableBlock(rows, index, resolveLink) {
    const [headerRow, separatorRow, ...bodyRows] = rows
    if (!headerRow || !separatorRow) {
        return createParagraphBlock(rows, index, resolveLink)
    }

    const headers = splitTableRow(headerRow).map((cell, cellIndex) => ({
        key: `table-header-${index}-${cellIndex}`,
        parts: buildInlineParts(cell, resolveLink),
    }))

    return {
        key: `table-${index}`,
        isTable: true,
        headers,
        rows: bodyRows.map((row, rowIndex) => ({
            key: `table-row-${index}-${rowIndex}`,
            cells: splitTableRow(row).map((cell, cellIndex) => ({
                key: `table-cell-${index}-${rowIndex}-${cellIndex}`,
                parts: buildInlineParts(cell, resolveLink),
            })),
        })),
    }
}

function splitTableRow(row) {
    return row
        .trim()
        .replace(/^\|/, '')
        .replace(/\|$/, '')
        .split('|')
        .map((cell) => cell.trim())
}

function isTableSeparator(line) {
    const cells = splitTableRow(line)
    return cells.length > 0 && cells.every((cell) => /^:?-{3,}:?$/.test(cell))
}

export function parseMarkdown(markdown = '', options = {}) {
    const resolveUrl = options.resolveUrl || sanitizeUrl
    const resolveLink = options.resolveLink || ((url) => ({ url: resolveUrl(url) }))
    const lines = markdown.replace(/\r\n/g, '\n').split('\n')
    const blocks = []
    let paragraphLines = []
    let listItems = []
    let blockquoteLines = []
    let tableRows = []
    let codeBlockLines = []
    let codeBlockLanguage = ''
    let inCodeBlock = false

    const flushParagraph = () => {
        if (paragraphLines.length) {
            blocks.push(createParagraphBlock(paragraphLines, blocks.length, resolveLink))
            paragraphLines = []
        }
    }

    const flushList = () => {
        if (listItems.length) {
            blocks.push(createListBlock(listItems, blocks.length, resolveLink))
            listItems = []
        }
    }

    const flushBlockquote = () => {
        if (blockquoteLines.length) {
            blocks.push(createBlockquoteBlock(blockquoteLines, blocks.length, resolveLink))
            blockquoteLines = []
        }
    }

    const flushTable = () => {
        if (tableRows.length) {
            blocks.push(createTableBlock(tableRows, blocks.length, resolveLink))
            tableRows = []
        }
    }

    const flushCodeBlock = () => {
        if (!inCodeBlock) {
            return
        }

        if (codeBlockLanguage === MERMAID_LANGUAGE) {
            blocks.push(
                createMermaidBlock(blocks.length, {
                    mermaidSource: codeBlockLines.join('\n'),
                })
            )
        } else {
            blocks.push(createCodeBlock(codeBlockLines, blocks.length, codeBlockLanguage))
        }

        codeBlockLines = []
        codeBlockLanguage = ''
        inCodeBlock = false
    }

    lines.forEach((line, lineIndex) => {
        const trimmed = line.trim()

        if (trimmed.startsWith('```')) {
            flushParagraph()
            flushList()
            flushBlockquote()
            flushTable()

            if (inCodeBlock) {
                flushCodeBlock()
            } else {
                inCodeBlock = true
                codeBlockLines = []
                codeBlockLanguage = normalizeFenceLanguage(trimmed.slice(3))
            }
            return
        }

        if (inCodeBlock) {
            codeBlockLines.push(line)
            return
        }

        if (!trimmed) {
            flushParagraph()
            flushList()
            flushBlockquote()
            flushTable()
            return
        }

        const imageMatch = trimmed.match(/^!\[([^\]]*)\]\(([^)]+)\)$/)
        if (imageMatch) {
            flushParagraph()
            flushList()
            flushBlockquote()
            flushTable()

            const imageUrl = imageMatch[2]

            if (isMermaidReference(imageUrl)) {
                blocks.push(
                    createMermaidBlock(blocks.length, {
                        mermaidSrc: resolveUrl(imageUrl),
                        alt: imageMatch[1],
                    })
                )
            } else {
                blocks.push({
                    key: `image-${blocks.length}`,
                    isImage: true,
                    alt: imageMatch[1],
                    src: resolveUrl(imageUrl),
                })
            }
            return
        }

        const headingMatch = trimmed.match(/^(#{1,3})\s+(.*)$/)
        if (headingMatch) {
            flushParagraph()
            flushList()
            flushBlockquote()
            flushTable()
            const level = headingMatch[1].length
            blocks.push(createHeadingBlock(level, headingMatch[2], blocks.length, resolveLink))
            return
        }

        const blockquoteMatch = trimmed.match(/^>\s?(.*)$/)
        if (blockquoteMatch) {
            flushParagraph()
            flushList()
            flushTable()
            blockquoteLines.push(blockquoteMatch[1])
            return
        }

        const listMatch = line.match(/^(\s*)[-*]\s+(.*)$/)
        if (listMatch) {
            flushParagraph()
            flushBlockquote()
            flushTable()
            listItems.push({
                indent: listMatch[1].length,
                text: listMatch[2],
                ordered: false,
            })
            return
        }

        const orderedListMatch = line.match(/^(\s*)\d+\.\s+(.*)$/)
        if (orderedListMatch) {
            flushParagraph()
            flushBlockquote()
            flushTable()
            listItems.push({
                indent: orderedListMatch[1].length,
                text: orderedListMatch[2],
                ordered: true,
            })
            return
        }

        const looksLikeTable = trimmed.includes('|')
        if (looksLikeTable) {
            const nextLine = lines[lineIndex + 1]?.trim()
            if (tableRows.length > 0 || (nextLine && isTableSeparator(nextLine))) {
                flushParagraph()
                flushList()
                flushBlockquote()
                tableRows.push(trimmed)
                return
            }
        }

        flushList()
        flushBlockquote()
        flushTable()
        paragraphLines.push(trimmed)
    })

    flushParagraph()
    flushList()
    flushBlockquote()
    flushTable()
    flushCodeBlock()

    return assignAnchorIds(blocks)
}

function slugifyHeading(text) {
    return text
        .toLowerCase()
        .trim()
        .replace(/[^\w\s-]/g, '')
        .replace(/\s+/g, '-')
        .replace(/^-|-$/g, '')
}

function assignAnchorIds(blocks) {
    const used = new Map()

    return blocks.map((block) => {
        if (!(block.isHeading1 || block.isHeading2 || block.isHeading3)) {
            return { ...block, anchorId: block.key }
        }

        const label = extractTextFromParts(block.parts).trim()
        let slug = slugifyHeading(label) || block.key
        const seen = used.get(slug) || 0
        used.set(slug, seen + 1)

        if (seen > 0) {
            slug = `${slug}-${seen}`
        }

        return { ...block, anchorId: slug }
    })
}

function renderInlinePart(part) {
    if (part.isLink) {
        return `<a href="${part.url}" target="_blank" rel="noopener noreferrer">${part.label}</a>`
    }

    if (part.isStrong) {
        return `<strong>${part.text}</strong>`
    }

    if (part.isEmphasis) {
        return `<em>${part.text}</em>`
    }

    if (part.isCode) {
        return `<code>${part.text}</code>`
    }

    return part.text
}

function renderListItemHtml(item) {
    const nestedListHtml = item.children?.length
        ? item.childrenOrdered
            ? `<ol>${item.children.map((child) => renderListItemHtml(child)).join('')}</ol>`
            : `<ul>${item.children.map((child) => renderListItemHtml(child)).join('')}</ul>`
        : ''

    return `<li>${item.parts.map(renderInlinePart).join('')}${nestedListHtml}</li>`
}

export function markdownToHtml(markdown = '') {
    return parseMarkdown(markdown)
        .map((block) => {
            if (block.isHeading1) {
                return `<h1>${block.parts.map(renderInlinePart).join('')}</h1>`
            }

            if (block.isHeading2) {
                return `<h2>${block.parts.map(renderInlinePart).join('')}</h2>`
            }

            if (block.isHeading3) {
                return `<h3>${block.parts.map(renderInlinePart).join('')}</h3>`
            }

            if (block.isList) {
                const itemsHtml = block.items
                    .map((item) => renderListItemHtml(item))
                    .join('')
                return block.ordered ? `<ol>${itemsHtml}</ol>` : `<ul>${itemsHtml}</ul>`
            }

            const paragraphHtml = block.lines
                .map((line) => line.parts.map(renderInlinePart).join(''))
                .join('<br/>')
            return `<p>${paragraphHtml}</p>`
        })
        .join('')
}