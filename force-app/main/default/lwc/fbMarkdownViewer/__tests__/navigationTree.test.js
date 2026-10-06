import { applyExpandedBranches, expandNavigationToDocument, findBranchPathToDocument } from '../navigationTree'

describe('navigationTree', () => {
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

    it('finds the branch path to a nested document', () => {
        expect(findBranchPathToDocument(navigationItems, 'architecture/architecture-overview.md')).toEqual(['root-1'])
    })

    it('returns an empty branch path for top-level documents', () => {
        expect(findBranchPathToDocument(navigationItems, 'system-overview.md')).toEqual([])
    })

    it('expands ancestor branches without collapsing existing expanded nodes', () => {
        const expandedItems = expandNavigationToDocument(
            [
                {
                    label: 'Architecture',
                    name: 'root-1',
                    expanded: true,
                    items: [
                        {
                            label: 'Architecture Overview',
                            name: 'architecture/architecture-overview.md',
                            path: 'architecture/architecture-overview.md',
                        },
                    ],
                },
            ],
            'architecture/architecture-overview.md'
        )

        expect(expandedItems[0].expanded).toBe(true)
    })

    it('marks only the ancestor branches as expanded', () => {
        const expandedItems = expandNavigationToDocument(navigationItems, 'architecture/architecture-overview.md')

        expect(expandedItems[0].expanded).toBeUndefined()
        expect(expandedItems[1].expanded).toBe(true)
        expect(expandedItems[1].items[0].expanded).toBeUndefined()
    })

    it('preserves unrelated branches when expanding to a nested document', () => {
        const items = [
            {
                label: 'Open Group',
                name: 'root-0',
                expanded: true,
                items: [{ label: 'Other', name: 'other.md', path: 'other.md' }],
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

        const expandedItems = applyExpandedBranches(items, new Set(['root-1']))

        expect(expandedItems[0].expanded).toBe(true)
        expect(expandedItems[1].expanded).toBe(true)
    })
})
