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

public struct FileSearchIndex: Sendable {
    public var rootID: NodeID
    public var entries: [FileSearchIndexEntry]

    public init(
        snapshot: FileTreeSnapshot,
        rootedAt rootID: NodeID,
        isCancelled: @Sendable () -> Bool = { false }
    ) {
        self.rootID = rootID
        guard let root = snapshot[rootID] else {
            self.entries = []
            return
        }

        var entries: [FileSearchIndexEntry] = []
        var stack = root.children.reversed().compactMap { childID -> (NodeID, String)? in
            guard let child = snapshot[childID] else { return nil }
            return (child.id, Self.displayName(for: child))
        }

        while let (id, relativePath) = stack.popLast(), let node = snapshot[id] {
            if isCancelled() {
                self.entries = []
                return
            }

            let category = FileCategoryClassifier.category(for: node)
            entries.append(
                FileSearchIndexEntry(
                    nodeID: node.id,
                    name: Self.displayName(for: node),
                    relativePath: relativePath,
                    kind: node.kind,
                    category: category,
                    allocatedBytes: node.allocatedSize
                )
            )

            for childID in node.children.reversed() {
                guard let child = snapshot[childID] else { continue }
                stack.append((child.id, relativePath + "/" + Self.displayName(for: child)))
            }
        }

        self.entries = entries
    }

    public func search(
        query: String,
        limit: Int = 30,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> [FileSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty, limit > 0 else { return [] }

        var results: [FileSearchResult] = []
        for entry in entries {
            if isCancelled() {
                return []
            }
            guard entry.matches(normalizedQuery) else { continue }
            insert(
                FileSearchResult(
                    nodeID: entry.nodeID,
                    name: entry.name,
                    relativePath: entry.relativePath,
                    kind: entry.kind,
                    category: entry.category,
                    allocatedBytes: entry.allocatedBytes
                ),
                into: &results,
                limit: limit
            )
        }
        return results
    }

    private func insert(_ result: FileSearchResult, into results: inout [FileSearchResult], limit: Int) {
        let insertionIndex = results.firstIndex { existing in
            if existing.allocatedBytes == result.allocatedBytes {
                return result.relativePath.localizedStandardCompare(existing.relativePath) == .orderedAscending
            }
            return result.allocatedBytes > existing.allocatedBytes
        } ?? results.endIndex

        results.insert(result, at: insertionIndex)
        if results.count > limit {
            results.removeLast(results.count - limit)
        }
    }

    private static func displayName(for node: FileNode) -> String {
        if !node.name.isEmpty { return node.name }
        return node.url?.lastPathComponent.isEmpty == false ? node.url?.lastPathComponent ?? node.name : node.url?.path ?? node.name
    }
}

public struct FileSearchIndexEntry: Hashable, Sendable {
    public var nodeID: NodeID
    public var name: String
    public var relativePath: String
    public var kind: NodeKind
    public var category: FileCategory
    public var allocatedBytes: Int64
    public var matchText: String

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
        self.matchText = [
            name,
            relativePath,
            kind.rawValue,
            category.rawValue
        ]
        .joined(separator: "\n")
        .lowercased()
    }

    public func matches(_ normalizedQuery: String) -> Bool {
        matchText.contains(normalizedQuery)
    }
}

public extension FileTreeSnapshot {
    func search(query: String, rootedAt rootID: NodeID, limit: Int = 30) -> [FileSearchResult] {
        FileSearchIndex(snapshot: self, rootedAt: rootID).search(query: query, limit: limit)
    }
}
