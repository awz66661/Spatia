import Foundation

public struct SafetyPolicy: Sendable {
    public var pathRiskPolicy: PathRiskPolicy

    public init(pathRiskPolicy: PathRiskPolicy = PathRiskPolicy()) {
        self.pathRiskPolicy = pathRiskPolicy
    }

    public func trashDecision(for node: FileNode) -> TrashDecision {
        if let reason = blockReason(for: node.scanState) {
            return .blocked(reason: reason)
        }

        return trashDecision(
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

    private func blockReason(for scanState: ScanState) -> String? {
        switch scanState {
        case .complete:
            return nil
        case .scanning:
            return "This item is still being scanned, so Spatia will not move it to Trash."
        case .skipped:
            return "This item was skipped during scanning, so Spatia will not move it to Trash."
        case .failed:
            return "This item could not be fully scanned, so Spatia will not move it to Trash."
        }
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
