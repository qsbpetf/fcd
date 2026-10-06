import {
    applyTocFixedLayout,
    clearTocFixedLayout,
    resolveTocFixedTopPx,
    TOC_FIXED_MIN_TOP_PX,
} from '../tocLayout'

describe('tocLayout', () => {
    it('applies fixed layout from column bounds', () => {
        const column = {
            getBoundingClientRect: () => ({
                top: 240,
                left: 900,
                width: 200,
            }),
        }
        const toc = { style: {} }
        const list = { scrollTop: 42 }

        const result = applyTocFixedLayout(column, toc, list)
        expect(result).toEqual({ applied: true, topPx: 240 })
        expect(toc.style.position).toBe('fixed')
        expect(toc.style.top).toBe('240px')
        expect(toc.style.left).toBe('900px')
        expect(toc.style.width).toBe('200px')
        expect(list.scrollTop).toBe(0)
    })

    it('uses cached top offset when provided', () => {
        const column = {
            getBoundingClientRect: () => ({
                top: 240,
                left: 900,
                width: 200,
            }),
        }
        const toc = { style: {} }

        const result = applyTocFixedLayout(column, toc, null, { cachedTopPx: 180 })
        expect(result.topPx).toBe(180)
        expect(toc.style.top).toBe('180px')
    })

    it('falls back to minimum top when column top is too small', () => {
        expect(resolveTocFixedTopPx(-20, null)).toBe(TOC_FIXED_MIN_TOP_PX)
    })

    it('clears fixed layout when column is hidden', () => {
        const column = {
            getBoundingClientRect: () => ({
                top: 0,
                left: 0,
                width: 0,
            }),
        }
        const toc = {
            style: {
                position: 'fixed',
                top: '240px',
                left: '0px',
                width: '0px',
                maxHeight: '100px',
            },
        }

        expect(applyTocFixedLayout(column, toc)).toEqual({ applied: false, topPx: null })
        expect(toc.style.position).toBe('')
        expect(toc.style.top).toBe('')
    })

    it('clears fixed layout styles', () => {
        const toc = {
            style: {
                position: 'fixed',
                top: '240px',
                left: '900px',
                width: '200px',
                maxHeight: '100px',
            },
        }

        clearTocFixedLayout(toc)
        expect(toc.style.position).toBe('')
        expect(toc.style.maxHeight).toBe('')
    })
})
