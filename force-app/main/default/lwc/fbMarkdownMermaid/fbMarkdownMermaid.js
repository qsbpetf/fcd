import { LightningElement, api } from 'lwc'
import { applyReadableSvgTextStyles, ensureMermaidLoaded, ensureSvgLabels } from './mermaidLoader'

export default class FbMarkdownMermaid extends LightningElement {
    @api mermaidSource
    @api mermaidSrc
    @api alt

    fetchedSource
    error
    renderError
    isLoading = false

    _instanceId
    _renderSequence = 0
    _lastRenderedSource
    _renderScheduled = false

    get displaySource() {
        return this.mermaidSource || this.fetchedSource || ''
    }

    get hasSource() {
        return Boolean(this.displaySource)
    }

    get placeholderLabel() {
        return this.alt || 'Mermaid diagram'
    }

    get showSourceFallback() {
        return Boolean(this.renderError && this.displaySource)
    }

    connectedCallback() {
        this._instanceId = `${Date.now()}-${Math.random().toString(36).slice(2)}`

        if (!this.mermaidSource && this.mermaidSrc) {
            this.loadMermaidSource()
        }
    }

    renderedCallback() {
        this.scheduleDiagramRender()
    }

    scheduleDiagramRender() {
        const source = this.displaySource

        if (this.isLoading || !source || source === this._lastRenderedSource) {
            return
        }

        if (this._renderScheduled) {
            return
        }

        this._renderScheduled = true

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        Promise.resolve().then(async () => {
            this._renderScheduled = false
            await this.renderDiagram(source)
        })
    }

    async loadMermaidSource() {
        this.isLoading = true
        this.error = undefined
        this._lastRenderedSource = null

        try {
            const response = await fetch(this.mermaidSrc)

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`)
            }

            this.fetchedSource = await response.text()
        } catch (loadError) {
            this.error = 'Could not load the diagram source.'
        } finally {
            this.isLoading = false
        }
    }

    async renderDiagram(source) {
        const host = this.template.querySelector('.mermaid-render-host')

        if (!host) {
            return
        }

        try {
            await ensureMermaidLoaded()
            this.renderError = undefined

            const renderId = `mermaid-${this._instanceId}-${++this._renderSequence}`
            const preparedSource = ensureSvgLabels(source)
            const { svg, bindFunctions } = await window.mermaid.render(renderId, preparedSource)

            host.innerHTML = svg
            bindFunctions?.(host)
            applyReadableSvgTextStyles(host)
            this._lastRenderedSource = source
        } catch (diagramError) {
            this.renderError = 'The diagram could not be rendered.'
            host.innerHTML = ''
            this._lastRenderedSource = null
        }
    }
}