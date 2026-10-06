import { LightningElement, api } from 'lwc'
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { ensureHighlightLoaded, highlightCodeElement } from './highlightLoader'

export default class FbMarkdownCodeBlock extends LightningElement {
    @api code
    @api language

    _lastHighlightedCode
    _lastHighlightedLanguage
    _highlightScheduled = false

    get showLanguageLabel() {
        return Boolean(this.language)
    }

    get languageLabel() {
        return (this.language || '').toUpperCase()
    }

    connectedCallback() {
        ensureHighlightLoaded(this).catch(() => {})
    }

    renderedCallback() {
        if (this.code === this._lastHighlightedCode && this.language === this._lastHighlightedLanguage) {
            return
        }

        this.scheduleHighlighting()
    }

    scheduleHighlighting() {
        if (this._highlightScheduled) {
            return
        }

        this._highlightScheduled = true

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        Promise.resolve().then(async () => {
            this._highlightScheduled = false
            await this.applyHighlighting()
        })
    }

    async applyHighlighting() {
        const codeElement = this.template.querySelector('.code-block-code')

        if (!codeElement || !this.code) {
            return
        }

        try {
            await ensureHighlightLoaded(this)
            highlightCodeElement(codeElement, this.code, this.language)
        } catch (highlightError) {
            codeElement.textContent = this.code
        }

        this._lastHighlightedCode = this.code
        this._lastHighlightedLanguage = this.language
    }

    handleCopyClick() {
        const text = this.code || ''

        if (!text) {
            return
        }

        if (navigator.clipboard?.writeText && window.isSecureContext) {
            navigator.clipboard
                .writeText(text)
                .then(() => {
                    this.notifyCopied()
                })
                .catch(() => {
                    this.fallbackCopy(text)
                })
            return
        }

        this.fallbackCopy(text)
    }

    fallbackCopy(text) {
        const textArea = document.createElement('textarea')
        textArea.value = text
        textArea.style.position = 'fixed'
        textArea.style.left = '-9999px'
        textArea.style.top = '-9999px'
        document.body.appendChild(textArea)
        textArea.focus()
        textArea.select()

        try {
            document.execCommand('copy')
            this.notifyCopied()
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Could not copy',
                    message: 'Could not copy the code to the clipboard.',
                    variant: 'error',
                })
            )
        } finally {
            document.body.removeChild(textArea)
        }
    }

    notifyCopied() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Copied',
                message: 'The code was copied to the clipboard.',
                variant: 'success',
            })
        )
    }
}