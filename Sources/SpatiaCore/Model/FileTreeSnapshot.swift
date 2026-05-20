import Foundation

public struct FileTreeSnapshot: Sendable {
    public var nodes: [FileNode]
    public var rootID: NodeID

    public init(nodes: [FileNode], rootID: NodeID) {
        self.nodes = nodes
        self.rootID = rootID
    }

    public var root: FileNode? {
        self[rootID]
    }

    public subscript(id: NodeID) -> FileNode? {
        guard id >= 0 else { return nil }
        let index = Int(id)
        guard nodes.indices.contains(index) else { return nil }
        return nodes[index]
    }

    public func children(of id: NodeID) -> [FileNode] {
        guard let node = self[id] else { return [] }
        return node.children.compactMap { self[$0] }
    }

    public func breadcrumb(for id: NodeID) -> [FileNode] {
        var path: [FileNode] = []
        var currentID: NodeID? = id

        while let id = currentID, let node = self[id] {
            path.append(node)
            currentID = node.parentID
        }

        return path.reversed()
    }

    public func subtreeIDs(rootedAt id: NodeID) -> [NodeID] {
        guard let node = self[id] else { return [] }

        var ids = [node.id]
        for childID in node.children {
            ids.append(contentsOf: subtreeIDs(rootedAt: childID))
        }
        return ids
    }

    public mutating func detachSubtree(rootedAt id: NodeID) -> RemovedSubtreeSummary? {
        guard id != rootID, let node = self[id], let parentID = node.parentID, self[parentID] != nil else {
            return nil
        }

        let removedIDs = subtreeIDs(rootedAt: id)
        guard !removedIDs.isEmpty else { return nil }

        var summary = removedIDs.reduce(into: RemovedSubtreeSummary()) { partial, removedID in
            guard let removedNode = self[removedID] else { return }
            switch removedNode.kind {
            case .directory, .package:
                partial.folderCount += 1
            case .file, .symlink, .other:
                partial.fileCount += 1
            }
        }
        summary.logicalBytes = node.logicalSize
        summary.allocatedBytes = node.allocatedSize

        nodes[Int(parentID)].children.removeAll { $0 == id }

        var ancestorID: NodeID? = parentID
        while let currentID = ancestorID, let current = self[currentID] {
            nodes[Int(currentID)].logicalSize = max(0, current.logicalSize - summary.logicalBytes)
            nodes[Int(currentID)].allocatedSize = max(0, current.allocatedSize - summary.allocatedBytes)
            ancestorID = current.parentID
        }

        for removedID in removedIDs {
            nodes[Int(removedID)].logicalSize = 0
            nodes[Int(removedID)].allocatedSize = 0
            nodes[Int(removedID)].children = []
            nodes[Int(removedID)].scanState = .skipped
        }

        return summary
    }
}

public struct RemovedSubtreeSummary: Hashable, Sendable {
    public var fileCount: Int
    public var folderCount: Int
    public var logicalBytes: Int64
    public var allocatedBytes: Int64

    public init(
        fileCount: Int = 0,
        folderCount: Int = 0,
        logicalBytes: Int64 = 0,
        allocatedBytes: Int64 = 0
    ) {
        self.fileCount = fileCount
        self.folderCount = folderCount
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
    }
}
