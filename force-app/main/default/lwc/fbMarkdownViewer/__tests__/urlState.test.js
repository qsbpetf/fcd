import { buildUrlState, normalizeDocPath, parseUrlState, serializeStateKey, URL_STATE_KEYS } from '../urlState'

describe('urlState', () => {
    it('normalizes doc paths and adds .md suffix when missing', () => {
        expect(normalizeDocPath('integrations/fast2-technical-deep-dive')).toBe(
            'integrations/fast2-technical-deep-dive.md'
        )
        expect(normalizeDocPath('system-overview.md')).toBe('system-overview.md')
    })

    it('rejects unsafe or absolute doc paths', () => {
        expect(normalizeDocPath('../secret.md')).toBeNull()
        expect(normalizeDocPath('https://example.com/doc.md')).toBeNull()
        expect(normalizeDocPath('/absolute/doc.md')).toBeNull()
    })

    it('parses page reference state into doc, block and q', () => {
        expect(
            parseUrlState({
                state: {
                    [URL_STATE_KEYS.DOC]: 'architecture/architecture-overview',
                    [URL_STATE_KEYS.BLOCK]: 'heading-2',
                    [URL_STATE_KEYS.Q]: 'smartform',
                },
            })
        ).toEqual({
            doc: 'architecture/architecture-overview.md',
            block: 'heading-2',
            q: 'smartform',
        })
    })

    it('builds page state and clears removed keys', () => {
        expect(
            buildUrlState(
                { doc: 'system-overview.md', block: null, q: null },
                {
                    [URL_STATE_KEYS.DOC]: 'old.md',
                    [URL_STATE_KEYS.BLOCK]: 'heading-1',
                    [URL_STATE_KEYS.Q]: 'old',
                    c__other: 'keep-me',
                }
            )
        ).toEqual({
            c__other: 'keep-me',
            [URL_STATE_KEYS.DOC]: 'system-overview.md',
        })
    })

    it('serializes state keys for loop detection', () => {
        expect(serializeStateKey({ doc: 'a.md', block: 'heading-1', q: 'term' })).toBe('a.md|heading-1|term')
    })
})
