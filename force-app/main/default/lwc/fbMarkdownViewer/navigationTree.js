export function findBranchPathToDocument(nodes = [], targetPath, branchPath = []) {
    for (const node of nodes) {
        if (node.path === targetPath) {
            return branchPath
        }

        if (node.items?.length) {
            const nestedPath = findBranchPathToDocument(node.items, targetPath, [...branchPath, node.name])

            if (nestedPath) {
                return nestedPath
            }
        }
    }

    return null
}

export function applyExpandedBranches(nodes = [], expandedBranchNames = new Set()) {
    return nodes.map((node) => {
        if (!node.items?.length) {
            return { ...node }
        }

        return {
            ...node,
            expanded: expandedBranchNames.has(node.name) || Boolean(node.expanded),
            items: applyExpandedBranches(node.items, expandedBranchNames),
        }
    })
}

export function expandNavigationToDocument(nodes, targetPath) {
    const branchPath = findBranchPathToDocument(nodes, targetPath)

    if (!branchPath) {
        return nodes
    }

    return applyExpandedBranches(nodes, new Set(branchPath))
}