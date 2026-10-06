import { LightningElement, wire } from 'lwc'
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation'
import markdownDemo from '@salesforce/resourceUrl/MarkdownDemo'
import { parseMarkdown } from './markdownParser'
import { buildDocumentIndex, collectDocumentPaths, searchDocuments } from './searchIndex'
import { expandNavigationToDocument } from './navigationTree'
import {
    buildTableOfContentsView,
    extractTableOfContents,
    resolveActiveTocBlockKey,
} from './tableOfContents'
import { buildUrlState, parseUrlState, serializeStateKey } from './urlState'
import { applyTocFixedLayout, clearTocFixedLayout } from './tocLayout'

const DEFAULT_ERROR_MESSAGE = 'Could not read the documentation.'
const DEFAULT_INDEX_FILE = 'index.json'
const CANDIDATE_ROOTS = ['', 'docs']
const SEARCH_DEBOUNCE_MS = 300
const SEARCH_SCOPE_ALL = 'all'
const SEARCH_SCOPE_CURRENT = 'current'
const TOC_SCROLL_LOCK_MS = 900

export default class FbMarkdownViewer extends NavigationMixin(LightningElement) {
    blocks = []
    navigationItems = []
    selectedItem
    selectedDocumentLabel
    error
    isLoading = true
    libraryRoot = ''
    searchQuery = ''
    searchScope = SEARCH_SCOPE_ALL
    searchResults = []
    searchIndex = []
    isSearchIndexReady = false
    isSearchIndexBuilding = false
    highlightedBlockKey
    highlightQuery
    searchDebounceTimer
    currentPageReference
    pendingUrlState
    lastSyncedStateKey = ''
    isLibraryReady = false
    isApplyingUrlState = false
    firstDocument
    tableOfContents = []
    activeTocBlockKey
    tocScrollLockKey
    tocScrollLockUntil = 0
    boundUpdateActiveToc
    boundUpdateTocLayout
    tocFixedTopPx = null

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (!pageRef) {
            return
        }

        this.currentPageReference = pageRef

        if (!this.isLibraryReady) {
            this.pendingUrlState = parseUrlState(pageRef)
            return
        }

        this.applyUrlStateFromPageReference(pageRef)
    }

    async connectedCallback() {
        await this.loadLibrary()
    }

    disconnectedCallback() {
        this.teardownTocScrollSpy()
        clearTimeout(this.searchDebounceTimer)
    }

    async loadLibrary() {
        try {
            this.isLoading = true
            this.error = undefined

            const navigationIndex = await this.loadIndex()
            const normalizedNavigation = this.normalizeNavigation(navigationIndex)

            this.navigationItems = normalizedNavigation.items
            this.firstDocument = normalizedNavigation.firstDocument
            this.isLibraryReady = true

            const urlState = this.pendingUrlState ?? parseUrlState(this.currentPageReference)

            if (urlState.doc) {
                try {
                    await this.applyUrlState(urlState, { syncUrl: false })
                } catch (urlError) {
                    this.error = urlError?.message || DEFAULT_ERROR_MESSAGE

                    if (this.firstDocument) {
                        await this.loadDocument(this.firstDocument.path, this.firstDocument.label, { syncUrl: false })
                    } else {
                        this.blocks = []
                    }
                }
            } else if (this.firstDocument) {
                await this.loadDocument(this.firstDocument.path, this.firstDocument.label, { syncUrl: false })
            } else {
                this.blocks = []
            }

            this.buildSearchIndexInBackground()
        } catch (error) {
            this.blocks = []
            this.error = error?.message || DEFAULT_ERROR_MESSAGE
        } finally {
            this.isLoading = false
        }
    }

    async applyUrlStateFromPageReference(pageRef) {
        if (this.isApplyingUrlState) {
            return
        }

        const urlState = parseUrlState(pageRef)
        const stateKey = serializeStateKey(urlState)

        if (stateKey === this.lastSyncedStateKey) {
            return
        }

        this.isApplyingUrlState = true

        try {
            if (!urlState.doc) {
                if (this.firstDocument && this.selectedItem !== this.firstDocument.path) {
                    await this.loadDocument(this.firstDocument.path, this.firstDocument.label, { syncUrl: false })
                }

                this.lastSyncedStateKey = stateKey
                return
            }

            await this.applyUrlState(urlState, { syncUrl: false })
            this.lastSyncedStateKey = stateKey
        } catch (urlError) {
            this.error = urlError?.message || DEFAULT_ERROR_MESSAGE
        } finally {
            this.isApplyingUrlState = false
        }
    }

    async applyUrlState(urlState, options = {}) {
        const { syncUrl = false } = options
        const targetNode = this.findDocumentNode(this.navigationItems, urlState.doc)

        if (!targetNode) {
            throw new Error(`Document ${urlState.doc} is not in the navigation.`)
        }

        this.navigationItems = expandNavigationToDocument(this.navigationItems, urlState.doc)

        if (urlState.q) {
            this.searchQuery = urlState.q
        }

        await this.loadDocument(targetNode.path, targetNode.label, {
            scrollToBlockKey: urlState.block || undefined,
            highlightQuery: urlState.q || undefined,
            syncUrl,
        })

        if (urlState.q && this.isSearchIndexReady) {
            this.runSearch(urlState.q)
        }
    }

    syncUrlState(urlState, replace = false) {
        const stateKey = serializeStateKey(urlState)

        if (stateKey === this.lastSyncedStateKey) {
            return
        }

        if (!this.currentPageReference) {
            return
        }

        this.lastSyncedStateKey = stateKey

        this[NavigationMixin.Navigate](
            {
                ...this.currentPageReference,
                state: buildUrlState(urlState, this.currentPageReference.state),
            },
            replace
        )
    }

    async buildSearchIndexInBackground() {
        const documentPaths = collectDocumentPaths(this.navigationItems)

        if (!documentPaths.length) {
            this.isSearchIndexReady = true
            return
        }

        this.isSearchIndexBuilding = true

        try {
            const indexResults = await Promise.all(
                documentPaths.map(async ({ path, label }) => {
                    try {
                        const response = await fetch(this.buildResourceUrl(path))

                        if (!response.ok) {
                            return null
                        }

                        const markdown = await response.text()
                        return buildDocumentIndex(path, label, markdown, (content) => parseMarkdown(content))
                    } catch {
                        return null
                    }
                })
            )

            this.searchIndex = indexResults.filter(Boolean)
            this.isSearchIndexReady = true

            if (this.searchQuery.trim().length >= 2) {
                this.runSearch(this.searchQuery)
            }
        } finally {
            this.isSearchIndexBuilding = false
        }
    }

    handleSearchInput(event) {
        this.searchQuery = event.detail?.value ?? event.target.value ?? ''
        clearTimeout(this.searchDebounceTimer)

        if (!this.searchQuery.trim()) {
            this.searchResults = []
            return
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchDebounceTimer = setTimeout(() => {
            this.runSearch(this.searchQuery)
        }, SEARCH_DEBOUNCE_MS)
    }

    handleSearchScopeAll() {
        this.searchScope = SEARCH_SCOPE_ALL

        if (this.searchQuery.trim()) {
            this.runSearch(this.searchQuery)
        }
    }

    handleSearchScopeCurrent() {
        this.searchScope = SEARCH_SCOPE_CURRENT

        if (this.searchQuery.trim()) {
            this.runSearch(this.searchQuery)
        }
    }

    handleSearchKeydown(event) {
        if (event.key === 'Escape') {
            this.clearSearch()
            return
        }

        if (event.key === 'Enter' && this.searchResults.length) {
            event.preventDefault()
            this.navigateToSearchResult(this.searchResults[0])
        }
    }

    handleSearchResultClick(event) {
        const resultKey = event.currentTarget.dataset.resultKey
        const result = this.searchResults.find((searchResult) => searchResult.resultKey === resultKey)

        if (result) {
            this.navigateToSearchResult(result)
        }
    }

    async navigateToSearchResult(result) {
        const targetNode = this.findDocumentNode(this.navigationItems, result.path)
        const label = targetNode?.label || this.createLabelFromPath(result.path)

        this.navigationItems = expandNavigationToDocument(this.navigationItems, result.path)
        this.isLoading = true

        try {
            await this.loadDocument(result.path, label, {
                scrollToBlockKey: result.blockKey || undefined,
                highlightQuery: this.searchQuery.trim(),
                syncUrl: true,
            })
        } catch (loadError) {
            this.blocks = []
            this.error = loadError?.message || DEFAULT_ERROR_MESSAGE
        } finally {
            this.isLoading = false
        }
    }

    clearSearch() {
        this.searchQuery = ''
        this.searchResults = []
        clearTimeout(this.searchDebounceTimer)

        if (this.selectedItem) {
            this.syncUrlState({
                doc: this.selectedItem,
                block: null,
                q: null,
            })
        }
    }

    runSearch(query) {
        if (!this.isSearchIndexReady) {
            return
        }

        this.searchResults = searchDocuments(this.searchIndex, query, {
            scopePath: this.searchScope === SEARCH_SCOPE_CURRENT ? this.selectedItem : undefined,
        })
    }

    async handleNavigationSelect(event) {
        const selectedPath = event.detail.name
        const selectedNode = this.findDocumentNode(this.navigationItems, selectedPath)

        if (!selectedNode || !selectedNode.path) {
            return
        }

        this.isLoading = true

        try {
            await this.loadDocument(selectedNode.path, selectedNode.label, { syncUrl: true })
        } catch (error) {
            this.blocks = []
            this.error = error?.message || DEFAULT_ERROR_MESSAGE
        } finally {
            this.isLoading = false
        }
    }

    async loadDocument(path, label, options = {}) {
        const { scrollToBlockKey, highlightQuery, syncUrl = false } = options
        const response = await fetch(this.buildResourceUrl(path))

        if (!response.ok) {
            throw new Error(`Could not fetch document ${path} (${response.status}).`)
        }

        const markdown = await response.text()
        const parsedBlocks = parseMarkdown(markdown, {
            resolveLink: (url) => this.resolveDocumentLink(url, path),
            resolveUrl: (url) => this.resolveDocumentUrl(url, path),
        })

        this.blocks = parsedBlocks.map((block) => ({
            ...block,
            highlightTerm: block.key === scrollToBlockKey ? highlightQuery || null : null,
        }))
        this.tableOfContents = extractTableOfContents(parsedBlocks)
        if (scrollToBlockKey) {
            this.lockTocHighlight(scrollToBlockKey)
        } else {
            this.tocScrollLockKey = null
            this.activeTocBlockKey = null
        }
        this.selectedItem = path
        this.selectedDocumentLabel = label
        this.error = undefined
        this.highlightedBlockKey = null
        this.highlightQuery = null

        await Promise.resolve()
        this.tocFixedTopPx = null
        this.setupTocScrollSpy()

        if (scrollToBlockKey) {
            await Promise.resolve()
            this.scrollToBlock(scrollToBlockKey, highlightQuery)
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            this.updateTocFixedLayout()
        })

        if (syncUrl && !this.isApplyingUrlState) {
            this.syncUrlState({
                doc: path,
                block: scrollToBlockKey || null,
                q: highlightQuery || null,
            })
        }
    }

    scrollToBlock(blockKey, highlightQuery) {
        if (blockKey) {
            this.lockTocHighlight(blockKey)
        }

        this.highlightedBlockKey = blockKey
        this.highlightQuery = highlightQuery || null

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            const section = this.template.querySelector(`[data-block-key="${blockKey}"]`)

            if (!section) {
                return
            }

            section.scrollIntoView({ behavior: 'smooth', block: 'start' })
            section.classList.add('search-hit')

            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                section.classList.remove('search-hit')
            }, 3000)
        })
    }

    lockTocHighlight(blockKey) {
        if (!blockKey) {
            return
        }

        this.tocScrollLockKey = blockKey
        this.tocScrollLockUntil = Date.now() + TOC_SCROLL_LOCK_MS
        this.activeTocBlockKey = blockKey
    }

    handleTocClick(event) {
        const blockKey = event.currentTarget.dataset.blockKey

        if (!blockKey) {
            return
        }

        this.scrollToBlock(blockKey, null)

        if (this.selectedItem && !this.isApplyingUrlState) {
            this.syncUrlState({
                doc: this.selectedItem,
                block: blockKey,
                q: null,
            })
        }
    }

    setupTocScrollSpy() {
        this.teardownTocScrollSpy()

        if (this.tableOfContents.length < 2) {
            return
        }

        if (!this.boundUpdateActiveToc) {
            this.boundUpdateActiveToc = () => this.updateActiveTocFromScroll()
        }

        if (!this.boundUpdateTocLayout) {
            this.boundUpdateTocLayout = () => {
                this.tocFixedTopPx = null
                this.updateTocFixedLayout()
            }
        }

        window.addEventListener('scroll', this.boundUpdateActiveToc, { passive: true })
        window.addEventListener('resize', this.boundUpdateTocLayout, { passive: true })
        this.updateActiveTocFromScroll()
        this.updateTocFixedLayout()
    }

    updateTocFixedLayout() {
        const column = this.template.querySelector('.docs-toc-column')
        const toc = this.template.querySelector('.docs-toc')
        const list = this.template.querySelector('.toc-list')

        if (!column || !toc) {
            return
        }

        const result = applyTocFixedLayout(column, toc, list, {
            cachedTopPx: this.tocFixedTopPx,
        })

        if (result.applied && this.tocFixedTopPx === null) {
            this.tocFixedTopPx = result.topPx
        }
    }

    updateActiveTocFromScroll() {
        if (this.tableOfContents.length < 2) {
            return
        }

        if (this.tocScrollLockKey && Date.now() < this.tocScrollLockUntil) {
            if (this.activeTocBlockKey !== this.tocScrollLockKey) {
                this.activeTocBlockKey = this.tocScrollLockKey
            }
            return
        }

        this.tocScrollLockKey = null

        const activeKey = resolveActiveTocBlockKey(this.tableOfContents, (blockKey) => {
            const section = this.template.querySelector(`[data-block-key="${blockKey}"]`)

            return section ? section.getBoundingClientRect().top : null
        })

        if (activeKey && this.activeTocBlockKey !== activeKey) {
            this.activeTocBlockKey = activeKey
        }
    }

    teardownTocScrollSpy() {
        if (this.boundUpdateActiveToc) {
            window.removeEventListener('scroll', this.boundUpdateActiveToc)
        }

        if (this.boundUpdateTocLayout) {
            window.removeEventListener('resize', this.boundUpdateTocLayout)
        }

        this.tocFixedTopPx = null
        clearTocFixedLayout(this.template.querySelector('.docs-toc'))
    }

    buildResourceUrl(path) {
        const normalizedPath = this.libraryRoot ? `${this.libraryRoot}/${path}` : path
        return `${markdownDemo}/${normalizedPath}`
    }

    resolveDocumentUrl(url, currentDocumentPath) {
        if (!url) {
            return '#'
        }

        const absoluteDocPath = this.extractDocsRelativePath(url)
        if (absoluteDocPath) {
            return this.buildResourceUrl(absoluteDocPath)
        }

        if (/^(https?:|mailto:|tel:|\/)/i.test(url)) {
            return url
        }

        const currentSegments = currentDocumentPath.split('/').slice(0, -1)
        const relativeSegments = url.split('/')
        const resolvedSegments = [...currentSegments]

        relativeSegments.forEach((segment) => {
            if (!segment || segment === '.') {
                return
            }

            if (segment === '..') {
                resolvedSegments.pop()
                return
            }

            resolvedSegments.push(segment)
        })

        return this.buildResourceUrl(resolvedSegments.join('/'))
    }

    resolveDocumentLink(url, currentDocumentPath) {
        const hashIndex = url.indexOf('#')
        const pathPart = hashIndex === -1 ? url : url.slice(0, hashIndex)
        const anchor = hashIndex === -1 ? undefined : decodeURIComponent(url.slice(hashIndex + 1))

        if (!pathPart) {
            return {
                url: `#${anchor || ''}`,
                anchor,
            }
        }

        const normalizedDocPath = this.normalizeDocumentPath(pathPart, currentDocumentPath)

        if (normalizedDocPath?.toLowerCase().endsWith('.md')) {
            return {
                url: '#',
                docPath: normalizedDocPath,
                anchor,
            }
        }

        return {
            url: this.resolveDocumentUrl(pathPart, currentDocumentPath),
        }
    }

    normalizeNavigation(nodes = [], parentKey = 'root') {
        let firstDocument

        const items = nodes.map((node, index) => {
            const key = `${parentKey}-${index}`
            const hasChildren = Array.isArray(node.children) && node.children.length > 0

            if (hasChildren) {
                const normalizedChildren = this.normalizeNavigation(node.children, key)

                if (!firstDocument && normalizedChildren.firstDocument) {
                    firstDocument = normalizedChildren.firstDocument
                }

                return {
                    label: node.label,
                    name: key,
                    items: normalizedChildren.items,
                }
            }

            const documentNode = {
                label: node.label,
                name: node.path,
                path: node.path,
            }

            if (!firstDocument) {
                firstDocument = documentNode
            }

            return documentNode
        })

        return {
            items,
            firstDocument,
        }
    }

    findDocumentNode(nodes = [], targetName) {
        for (const node of nodes) {
            if (node.name === targetName && node.path) {
                return node
            }

            if (node.items?.length) {
                const nestedNode = this.findDocumentNode(node.items, targetName)
                if (nestedNode) {
                    return nestedNode
                }
            }
        }

        return null
    }

    async handleDocumentLink(event) {
        const docPath = event.detail?.docPath
        const anchor = event.detail?.anchor
        if (!docPath && !anchor) {
            return
        }

        if (!docPath || docPath === this.selectedItem) {
            this.scrollToAnchor(anchor)
            return
        }

        const targetNode = this.findDocumentNode(this.navigationItems, docPath)
        const label = targetNode?.label || this.createLabelFromPath(docPath)

        this.navigationItems = expandNavigationToDocument(this.navigationItems, docPath)
        this.isLoading = true
        try {
            await this.loadDocument(docPath, label, { syncUrl: true })
            this.scrollToAnchor(anchor)
        } catch (error) {
            this.blocks = []
            this.error = error?.message || DEFAULT_ERROR_MESSAGE
        } finally {
            this.isLoading = false
        }
    }

    scrollToAnchor(anchor) {
        if (!anchor) {
            return
        }

        const block = this.blocks.find((entry) => entry.anchorId === anchor)
        if (block) {
            this.scrollToBlock(block.key)
        }
    }

    normalizeDocumentPath(url, currentDocumentPath) {
        if (!url) {
            return null
        }

        const absoluteDocPath = this.extractDocsRelativePath(url)
        if (absoluteDocPath) {
            return absoluteDocPath
        }

        if (/^(https?:|mailto:|tel:)/i.test(url)) {
            return null
        }

        if (url.startsWith('/')) {
            return null
        }

        const currentSegments = currentDocumentPath.split('/').slice(0, -1)
        const relativeSegments = url.split('/')
        const resolvedSegments = [...currentSegments]

        relativeSegments.forEach((segment) => {
            if (!segment || segment === '.') {
                return
            }

            if (segment === '..') {
                resolvedSegments.pop()
                return
            }

            resolvedSegments.push(segment)
        })

        return resolvedSegments.join('/')
    }

    extractDocsRelativePath(url) {
        const match = url.match(/\/docs\/(.+)$/)
        return match ? match[1] : null
    }

    createLabelFromPath(path) {
        const filename = path.split('/').pop()?.replace(/\.md$/i, '') || path
        return filename
            .split('-')
            .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
            .join(' ')
    }

    get hasBlocks() {
        return this.blocks.length > 0
    }

    get isSearchInputDisabled() {
        return !this.isSearchIndexReady && this.isSearchIndexBuilding
    }

    get searchScopeAllVariant() {
        return this.searchScope === SEARCH_SCOPE_ALL ? 'brand' : 'neutral'
    }

    get searchScopeCurrentVariant() {
        return this.searchScope === SEARCH_SCOPE_CURRENT ? 'brand' : 'neutral'
    }

    get showSearchResults() {
        return this.searchQuery.trim().length >= 2 && this.searchResults.length > 0
    }

    get showSearchNoResults() {
        return (
            this.searchQuery.trim().length >= 2 &&
            this.isSearchIndexReady &&
            !this.isSearchIndexBuilding &&
            this.searchResults.length === 0
        )
    }

    get showSearchIndexStatus() {
        return this.isSearchIndexBuilding
    }

    get showTableOfContents() {
        return this.tableOfContents.length >= 2
    }

    get displayTableOfContents() {
        return buildTableOfContentsView(this.tableOfContents, this.activeTocBlockKey)
    }

    async loadIndex() {
        const results = await Promise.all(
            CANDIDATE_ROOTS.map(async (root) => {
                const url = root ? `${markdownDemo}/${root}/${DEFAULT_INDEX_FILE}` : `${markdownDemo}/${DEFAULT_INDEX_FILE}`
                const response = await fetch(url)
                return { root, response }
            })
        )

        const successfulResult = results.find(({ response }) => response.ok)
        if (successfulResult) {
            this.libraryRoot = successfulResult.root
            return successfulResult.response.json()
        }

        const lastStatus = results[results.length - 1]?.response?.status
        throw new Error(`Could not fetch the index file (${lastStatus || 'unknown error'}).`)
    }
}