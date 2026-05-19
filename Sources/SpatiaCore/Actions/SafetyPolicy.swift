import Foundation

public struct SafetyPolicy: Sendable {
    public init() {}

    public func trashDecision(for url: URL, kind: NodeKind) -> TrashDecision {
        let path = url.standardizedFileURL.path

        if isSystemProtected(path) {
            return .blocked(reason: "System-protected locations can only be revealed in Finder.")
        }

        if isUserLibrary(path), !isUserCaches(path) {
            return .blocked(reason: "User Library items are blocked by default because deleting them can break apps or data.")
        }

        if isUserCaches(path) {
            return .needsConfirmation(warning: "Cache folders are usually replaceable, but apps may still rely on their contents.")
        }

        if kind == .package {
            return .needsConfirmation(warning: "This item is a package. It appears as one file in Finder but contains many files inside.")
        }

        return .allowed
    }

    private func isSystemProtected(_ path: String) -> Bool {
        let blockedPrefixes = [
            "/System",
            "/Library",
            "/private",
            "/bin",
            "/sbin",
            "/usr",
            "/Applications/Xcode.app"
        ]

        return blockedPrefixes.contains { prefix in
            path == prefix || path.hasPrefix(prefix + "/")
        }
    }

    private func isUserLibrary(_ path: String) -> Bool {
        let library = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .standardizedFileURL
            .path
        return path == library || path.hasPrefix(library + "/")
    }

    private func isUserCaches(_ path: String) -> Bool {
        let caches = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches", isDirectory: true)
            .standardizedFileURL
            .path
        return path == caches || path.hasPrefix(caches + "/")
    }
}

public enum TrashDecision: Equatable, Sendable {
    case allowed
    case needsConfirmation(warning: String)
    case blocked(reason: String)

    public var isBlocked: Bool {
        if case .blocked = self { return true }
        return false
    }
}
