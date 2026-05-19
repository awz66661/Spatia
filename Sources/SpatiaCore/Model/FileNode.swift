import Foundation

public struct FileNode: Identifiable, Hashable, Sendable {
    public let id: NodeID
    public let parentID: NodeID?

    public var name: String
    public var url: URL?

    public var kind: NodeKind
    public var flags: NodeFlags
    public var typeIdentifier: String?

    public var logicalSize: Int64
    public var allocatedSize: Int64

    public var modifiedAt: Date?
    public var children: [NodeID]

    public var scanState: ScanState

    public init(
        id: NodeID,
        parentID: NodeID?,
        name: String,
        url: URL?,
        kind: NodeKind,
        flags: NodeFlags = [],
        typeIdentifier: String? = nil,
        logicalSize: Int64 = 0,
        allocatedSize: Int64 = 0,
        modifiedAt: Date? = nil,
        children: [NodeID] = [],
        scanState: ScanState = .complete
    ) {
        self.id = id
        self.parentID = parentID
        self.name = name
        self.url = url
        self.kind = kind
        self.flags = flags
        self.typeIdentifier = typeIdentifier
        self.logicalSize = logicalSize
        self.allocatedSize = allocatedSize
        self.modifiedAt = modifiedAt
        self.children = children
        self.scanState = scanState
    }
}

public enum NodeKind: String, Hashable, Sendable {
    case directory
    case file
    case package
    case symlink
    case volume
    case other
}

public struct NodeFlags: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let permissionDenied = NodeFlags(rawValue: 1 << 0)
    public static let hidden = NodeFlags(rawValue: 1 << 1)
    public static let systemProtected = NodeFlags(rawValue: 1 << 2)
    public static let possiblySharedAPFSBlocks = NodeFlags(rawValue: 1 << 3)
    public static let iCloudPlaceholder = NodeFlags(rawValue: 1 << 4)
    public static let purgeable = NodeFlags(rawValue: 1 << 5)
}

public enum ScanState: String, Hashable, Sendable {
    case pending
    case scanning
    case complete
    case skipped
    case failed
}
