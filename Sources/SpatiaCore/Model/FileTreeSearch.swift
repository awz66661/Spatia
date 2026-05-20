import Foundation

public struct FileSearchResult: Identifiable, Hashable, Sendable {
    public var nodeID: NodeID
    public var name: String
    public var relativePath: String
    public var kind: NodeKind
    public var category: FileCategory
    public var allocatedBytes: Int64

    public var id: NodeID { nodeID }

    public init(
        nodeID: NodeID,
        name: String,
        relativePath: String,
        kind: NodeKind,
        category: FileCategory,
        allocatedBytes: Int64
    ) {
        self.nodeID = nodeID
        self.name = name
        self.relativePath = relativePath
        self.kind = kind
        self.category = category
        self.allocatedBytes = allocatedBytes
    }
}

public extension FileTreeSnapshot {
    func search(query: String, rootedAt rootID: NodeID, limit: Int = 30) -> [FileSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty, limit > 0, self[rootID] != nil else { return [] }

        var results: [FileSearchResult] = []
        var stack = Array(children(of: rootID).map(\.id).reversed())

        while let id = stack.popLast(), let node = self[id] {
            let relativePath = relativePath(from: rootID, to: node.id) ?? displayName(for: node)
            let category = FileCategoryClassifier.category(for: node)
            if matches(
                node: node,
                relativePath: relativePath,
                category: category,
                query: normalizedQuery
            ) {
                results.append(
                    FileSearchResult(
                        nodeID: node.id,
                        name: displayName(for: node),
                        relativePath: relativePath,
                        kind: node.kind,
                        category: category,
                        allocatedBytes: node.allocatedSize
                    )
                )
            }
            stack.append(contentsOf: node.children.reversed())
        }

        return results.sorted { lhs, rhs in
            if lhs.allocatedBytes == rhs.allocatedBytes {
                return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            }
            return lhs.allocatedBytes > rhs.allocatedBytes
        }
        .prefix(limit)
        .map { $0 }
    }

    private func matches(
        node: FileNode,
        relativePath: String,
        category: FileCategory,
        query: String
    ) -> Bool {
        displayName(for: node).lowercased().contains(query)
            || relativePath.lowercased().contains(query)
            || node.kind.rawValue.lowercased().contains(query)
            || category.rawValue.lowercased().contains(query)
    }

    private func displayName(for node: FileNode) -> String {
        if !node.name.isEmpty { return node.name }
        return node.url?.lastPathComponent.isEmpty == false ? node.url?.lastPathComponent ?? node.name : node.url?.path ?? node.name
    }
}
