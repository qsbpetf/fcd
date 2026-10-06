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

import { applyReadableSvgTextStyles, ensureSvgLabels, getMermaidInitConfig } from '../mermaidLoader'

describe('mermaidLoader', () => {
    it('disables html labels globally for LWC shadow DOM compatibility', () => {
        expect(getMermaidInitConfig().htmlLabels).toBe(false)
        expect(getMermaidInitConfig().flowchart.htmlLabels).toBe(false)
    })

    it('prepends svg label config to mermaid sources without frontmatter', () => {
        const prepared = ensureSvgLabels('flowchart LR\n  A-->B')

        expect(prepared).toContain('htmlLabels: false')
        expect(prepared).toContain('flowchart LR')
    })

    it('injects svg label config into existing frontmatter', () => {
        const prepared = ensureSvgLabels('---\nconfig:\n  theme: base\n---\nflowchart LR\n  A-->B')

        expect(prepared).toContain('htmlLabels: false')
        expect(prepared).toContain('theme: base')
    })

    it('sets readable fill colors on all svg text nodes', () => {
        const host = document.createElement('div')
        host.innerHTML =
            '<svg><text class="nodeLabel" fill="#eef6ff">Salesforce</text><text fill="#ffffff">Tele2</text></svg>'

        applyReadableSvgTextStyles(host)

        const labels = host.querySelectorAll('text')
        expect(labels[0].getAttribute('fill')).toBe('#16325c')
        expect(labels[1].getAttribute('fill')).toBe('#16325c')
    })

    it('styles labels inside foreignObject nodes', () => {
        const host = document.createElement('div')
        host.innerHTML = '<svg><foreignObject><div>Avy</div></foreignObject></svg>'

        applyReadableSvgTextStyles(host)

        const label = host.querySelector('foreignObject div')
        expect(label.style.color).toBe('rgb(22, 50, 92)')
        expect(label.style.fontFamily).toBe('Arial, sans-serif')
    })
})
