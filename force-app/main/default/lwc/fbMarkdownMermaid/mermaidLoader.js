import MERMAID_LIB from '@salesforce/resourceUrl/MermaidLib'
import { loadScript } from 'lightning/platformResourceLoader'

let loadPromise

const MERMAID_INIT = {
    startOnLoad: false,
    securityLevel: 'strict',
    htmlLabels: false,
    theme: 'base',
    themeVariables: {
        darkMode: false,
        background: '#ffffff',
        primaryColor: '#eef6ff',
        primaryBorderColor: '#234e70',
        primaryTextColor: '#16325c',
        secondaryColor: '#f8fafc',
        secondaryTextColor: '#16325c',
        tertiaryColor: '#ffffff',
        tertiaryTextColor: '#16325c',
        lineColor: '#5b6b7a',
        textColor: '#16325c',
        mainBkg: '#eef6ff',
        nodeBorder: '#234e70',
        clusterBkg: '#f8fafc',
        clusterBorder: '#234e70',
        titleColor: '#16325c',
        edgeLabelBackground: '#ffffff',
    },
    fontFamily: 'Arial, sans-serif',
    flowchart: {
        htmlLabels: false,
        useMaxWidth: true,
    },
    er: {
        htmlLabels: false,
    },
}

export function ensureSvgLabels(source = '') {
    const trimmed = source.trim()

    if (!trimmed) {
        return source
    }

    if (/htmlLabels\s*:\s*false/i.test(trimmed)) {
        return source
    }

    if (/^---[\s\S]*?---/m.test(trimmed)) {
        return trimmed.replace(
            /^---\s*\n/,
            '---\nconfig:\n  htmlLabels: false\n  flowchart:\n    htmlLabels: false\n'
        )
    }

    return `---
config:
  htmlLabels: false
  flowchart:
    htmlLabels: false
---
${trimmed}`
}

export function ensureMermaidLoaded() {
    if (!loadPromise) {
        loadPromise = loadScript(window, `${MERMAID_LIB}/mermaid.min.js`).then(() => {
            window.mermaid.initialize(MERMAID_INIT)
        })
    }

    return loadPromise
}

export function getMermaidInitConfig() {
    return MERMAID_INIT
}

const READABLE_TEXT_FILL = '#16325c'
const EDGE_LABEL_FILL = '#1f2a37'

export function applyReadableSvgTextStyles(host) {
    if (!host) {
        return
    }

    host.querySelectorAll('text, tspan').forEach((node) => {
        const className = node.getAttribute('class') || ''
        node.setAttribute('fill', className.includes('edgeLabel') ? EDGE_LABEL_FILL : READABLE_TEXT_FILL)
    })

    host.querySelectorAll('foreignObject div, foreignObject span, foreignObject p').forEach((node) => {
        node.style.color = READABLE_TEXT_FILL
        node.style.fontFamily = 'Arial, sans-serif'
        node.style.fontSize = '13px'
        node.style.lineHeight = '1.3'
    })
}