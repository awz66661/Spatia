import Foundation

public struct SafetyPolicy: Sendable {
    public var pathRiskPolicy: PathRiskPolicy

    public init(pathRiskPolicy: PathRiskPolicy = PathRiskPolicy()) {
        self.pathRiskPolicy = pathRiskPolicy
    }

    public func trashDecision(for node: FileNode) -> TrashDecision {
        trashDecision(
            for: node.url,
            name: node.name,
            kind: node.kind,
            flags: node.flags
        )
    }

    public func trashDecision(for url: URL, kind: NodeKind) -> TrashDecision {
        trashDecision(for: url, name: url.lastPathComponent, kind: kind)
    }

    public func trashDecision(
        for url: URL?,
        name: String,
        kind: NodeKind,
        flags: NodeFlags = []
    ) -> TrashDecision {
        let risk = pathRiskPolicy.risk(url: url, name: name, kind: kind, flags: flags)
        if let reason = risk.blockReason {
            return .blocked(reason: reason)
        }

        var warnings: [String] = []
        if let warning = risk.confirmationWarning {
            warnings.append(warning)
        }

        if flags.contains(.possiblySharedAPFSBlocks)
            || flags.contains(.iCloudPlaceholder)
            || flags.contains(.purgeable) {
            warnings.append("The displayed size may not equal the space recovered after moving this item to Trash.")
        }

        return warnings.isEmpty ? .allowed : .needsConfirmation(warnings: warnings)
    }
}

public enum TrashDecision: Equatable, Sendable {
    case allowed
    case needsConfirmation(warnings: [String])
    case blocked(reason: String)

    public var isBlocked: Bool {
        if case .blocked = self { return true }
        return false
    }

    public var warnings: [String] {
        if case let .needsConfirmation(warnings) = self { return warnings }
        return []
    }

    public var blockedReason: String? {
        if case let .blocked(reason) = self { return reason }
        return nil
    }
}
