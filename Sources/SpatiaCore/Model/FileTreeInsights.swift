import Foundation

public struct RankedNodeUsage: Hashable, Sendable {
    public var nodeID: NodeID
    public var allocatedBytes: Int64
    public var shareOfRoot: Double

    public init(nodeID: NodeID, allocatedBytes: Int64, shareOfRoot: Double) {
        self.nodeID = nodeID
        self.allocatedBytes = allocatedBytes
        self.shareOfRoot = shareOfRoot
    }
}

public struct CategoryUsage: Hashable, Sendable {
    public var category: FileCategory
    public var allocatedBytes: Int64
    public var itemCount: Int
    public var shareOfRoot: Double

    public init(category: FileCategory, allocatedBytes: Int64, itemCount: Int, shareOfRoot: Double) {
        self.category = category
        self.allocatedBytes = allocatedBytes
        self.itemCount = itemCount
        self.shareOfRoot = shareOfRoot
    }
}

public extension FileTreeSnapshot {
    func largestDescendantFiles(rootedAt rootID: NodeID, limit: Int) -> [RankedNodeUsage] {
        guard limit > 0, let root = self[rootID], root.allocatedSize > 0 else { return [] }

        var ranked: [RankedFileCandidate] = []
        var stack = root.children.reversed().compactMap { childID -> (NodeID, String)? in
            guard let child = self[childID] else { return nil }
            return (child.id, displayName(for: child))
        }

        while let (id, relativePath) = stack.popLast() {
            guard let node = self[id] else { continue }
            if isRankableFileLikeLeaf(node, rootID: rootID) {
                insertRanked(
                    RankedFileCandidate(
                        nodeID: node.id,
                        allocatedBytes: node.allocatedSize,
                        relativePath: relativePath
                    ),
                    into: &ranked,
                    limit: limit
                )
            }

            for childID in node.children.reversed() {
                guard let child = self[childID] else { continue }
                stack.append((child.id, relativePath + "/" + displayName(for: child)))
            }
        }

        return ranked.map { candidate in
            RankedNodeUsage(
                nodeID: candidate.nodeID,
                allocatedBytes: candidate.allocatedBytes,
                shareOfRoot: share(candidate.allocatedBytes, of: root.allocatedSize)
            )
        }
    }

    func categoryUsage(rootedAt rootID: NodeID) -> [CategoryUsage] {
        guard let root = self[rootID], root.allocatedSize > 0 else { return [] }

        var totals: [FileCategory: (allocatedBytes: Int64, itemCount: Int)] = [:]
        var stack = [root.id]
        while let id = stack.popLast(), let node = self[id] {
            guard node.allocatedSize > 0 else { continue }

            var hasPositiveChildren = false
            for childID in node.children.reversed() {
                guard let child = self[childID], child.allocatedSize > 0 else { continue }
                hasPositiveChildren = true
                stack.append(child.id)
            }
            if hasPositiveChildren {
                continue
            }

            let category = FileCategoryClassifier.category(for: node)
            let current = totals[category] ?? (allocatedBytes: 0, itemCount: 0)
            totals[category] = (
                allocatedBytes: current.allocatedBytes + node.allocatedSize,
                itemCount: current.itemCount + 1
            )
        }

        return totals.map { category, usage in
            CategoryUsage(
                category: category,
                allocatedBytes: usage.allocatedBytes,
                itemCount: usage.itemCount,
                shareOfRoot: share(usage.allocatedBytes, of: root.allocatedSize)
            )
        }
        .sorted { lhs, rhs in
            if lhs.allocatedBytes == rhs.allocatedBytes {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            return lhs.allocatedBytes > rhs.allocatedBytes
        }
    }

    func relativePath(from rootID: NodeID, to nodeID: NodeID) -> String? {
        guard let root = self[rootID], let node = self[nodeID] else { return nil }
        let breadcrumb = breadcrumb(for: nodeID)
        guard breadcrumb.contains(where: { $0.id == rootID }) else { return nil }

        if let rootURL = root.url?.standardizedFileURL,
           let nodeURL = node.url?.standardizedFileURL {
            let rootPath = rootURL.path
            let nodePath = nodeURL.path

            if nodePath == rootPath {
                return displayName(for: node)
            }

            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            if nodePath.hasPrefix(prefix) {
                return String(nodePath.dropFirst(prefix.count))
            }
        }

        guard let rootIndex = breadcrumb.firstIndex(where: { $0.id == rootID }) else { return nil }
        let path = breadcrumb.dropFirst(rootIndex + 1).map(displayName(for:))
        return path.isEmpty ? displayName(for: node) : path.joined(separator: "/")
    }

    private func isRankableFileLikeLeaf(_ node: FileNode, rootID: NodeID) -> Bool {
        guard node.id != rootID, node.allocatedSize > 0, node.children.isEmpty else { return false }

        switch node.kind {
        case .file, .package, .symlink, .other:
            return true
        case .directory:
            return false
        }
    }

    private func insertRanked(_ candidate: RankedFileCandidate, into ranked: inout [RankedFileCandidate], limit: Int) {
        let insertionIndex = ranked.firstIndex { existing in
            if existing.allocatedBytes == candidate.allocatedBytes {
                return candidate.relativePath.localizedStandardCompare(existing.relativePath) == .orderedAscending
            }
            return candidate.allocatedBytes > existing.allocatedBytes
        } ?? ranked.endIndex

        ranked.insert(candidate, at: insertionIndex)
        if ranked.count > limit {
            ranked.removeLast(ranked.count - limit)
        }
    }

    private func share(_ bytes: Int64, of total: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(bytes) / Double(total)
    }

    private func displayName(for node: FileNode) -> String {
        if !node.name.isEmpty { return node.name }
        return node.url?.lastPathComponent.isEmpty == false ? node.url?.lastPathComponent ?? node.name : node.url?.path ?? node.name
    }
}

private struct RankedFileCandidate {
    var nodeID: NodeID
    var allocatedBytes: Int64
    var relativePath: String
}
