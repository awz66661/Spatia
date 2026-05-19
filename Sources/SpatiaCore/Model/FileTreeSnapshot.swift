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
}
