import Foundation

public struct PathRiskPolicy: Sendable {
    public var homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory.standardizedFileURL
    }

    public func risk(for node: FileNode) -> PathRisk {
        risk(
            url: node.url,
            name: node.name,
            kind: node.kind,
            flags: node.flags
        )
    }

    public func risk(
        url: URL?,
        name: String,
        kind: NodeKind,
        flags: NodeFlags = []
    ) -> PathRisk {
        guard let url else {
            return PathRisk(classification: .missingURL)
        }

        let path = normalizedPath(url)
        let lowercasedName = name.lowercased()

        if flags.contains(.permissionDenied) {
            return PathRisk(classification: .permissionDenied)
        }

        if path == "/" {
            return PathRisk(classification: .systemRoot)
        }

        if isHomeRoot(path) {
            return PathRisk(classification: .homeRoot)
        }

        if isSystemProtected(path) || flags.contains(.systemProtected) {
            return PathRisk(classification: .systemProtected)
        }

        if isApplicationsRoot(path) || isProtectedApplicationBundle(path: path, name: lowercasedName, kind: kind) {
            return PathRisk(classification: .protectedApplicationBundle)
        }

        if isUserLibrary(path), !isUserCaches(path) {
            return PathRisk(classification: .userLibrary)
        }

        if isUserCaches(path) || isCacheLike(path: path, name: lowercasedName) {
            return PathRisk(classification: .userCache)
        }

        if isVolumeRoot(path) {
            return PathRisk(classification: .volumeRoot)
        }

        if kind == .package {
            return PathRisk(classification: .package)
        }

        if kind == .directory {
            return PathRisk(classification: .directory)
        }

        return PathRisk(classification: .ordinary)
    }

    public func isSystemCategory(url: URL?, flags: NodeFlags = []) -> Bool {
        guard let url else { return flags.contains(.systemProtected) }
        let path = normalizedPath(url)
        return flags.contains(.systemProtected)
            || path == "/"
            || isSystemProtected(path)
            || isApplicationsRoot(path)
            || isVolumeRoot(path)
    }

    public func isCacheCategory(url: URL?, name: String) -> Bool {
        let lowercasedName = name.lowercased()
        guard let url else {
            return lowercasedName == "caches" || lowercasedName.contains("cache")
        }
        return isUserCaches(normalizedPath(url)) || isCacheLike(path: normalizedPath(url), name: lowercasedName)
    }

    public func isScannerProtected(url: URL, flags: NodeFlags = []) -> Bool {
        let path = normalizedPath(url)
        return flags.contains(.systemProtected)
            || path == "/"
            || isSystemProtected(path)
            || isApplicationsRoot(path)
            || isVolumeRoot(path)
    }

    private func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func isHomeRoot(_ path: String) -> Bool {
        let homePath = homeDirectory.path
        return path == homePath
    }

    private func isSystemProtected(_ path: String) -> Bool {
        systemProtectedPrefixes.contains { prefix in
            path == prefix || path.hasPrefix(prefix + "/")
        }
    }

    private func isApplicationsRoot(_ path: String) -> Bool {
        path == "/Applications"
    }

    private func isProtectedApplicationBundle(path: String, name: String, kind: NodeKind) -> Bool {
        guard kind == .package || name.hasSuffix(".app") else { return false }
        return path == "/Applications" || path.hasPrefix("/Applications/")
    }

    private func isUserLibrary(_ path: String) -> Bool {
        let library = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .standardizedFileURL
            .path
        return path == library || path.hasPrefix(library + "/")
    }

    private func isUserCaches(_ path: String) -> Bool {
        let caches = homeDirectory
            .appendingPathComponent("Library/Caches", isDirectory: true)
            .standardizedFileURL
            .path
        return path == caches || path.hasPrefix(caches + "/")
    }

    private func isCacheLike(path: String, name: String) -> Bool {
        let lowercasedPath = path.lowercased()
        return lowercasedPath.contains("/library/caches/")
            || lowercasedPath.hasSuffix("/library/caches")
            || name == "caches"
            || name.contains("cache")
    }

    private func isVolumeRoot(_ path: String) -> Bool {
        let components = path.split(separator: "/")
        return components.count == 2 && components.first == "Volumes"
    }

    private let systemProtectedPrefixes = [
        "/System",
        "/Library",
        "/bin",
        "/sbin",
        "/usr",
        "/private"
    ]
}

public struct PathRisk: Hashable, Sendable {
    public var classification: PathRiskClassification

    public init(classification: PathRiskClassification) {
        self.classification = classification
    }

    public var isBlockedForTrash: Bool {
        classification.blockReason != nil
    }

    public var blockReason: String? {
        classification.blockReason
    }

    public var confirmationWarning: String? {
        classification.confirmationWarning
    }

    public var isVisuallyProtected: Bool {
        isBlockedForTrash || classification == .permissionDenied
    }
}

public enum PathRiskClassification: String, Hashable, Sendable {
    case ordinary
    case directory
    case package
    case userCache
    case userLibrary
    case homeRoot
    case systemRoot
    case systemProtected
    case protectedApplicationBundle
    case volumeRoot
    case permissionDenied
    case missingURL

    public var blockReason: String? {
        switch self {
        case .missingURL:
            return "This item does not have a filesystem URL."
        case .permissionDenied:
            return "This item could not be read, so Spatia will not move it to Trash."
        case .systemRoot:
            return "The filesystem root is blocked."
        case .systemProtected:
            return "System-protected locations can only be revealed in Finder."
        case .homeRoot:
            return "The home folder is blocked. Select a specific file or subfolder instead."
        case .userLibrary:
            return "User Library items are blocked by default because deleting them can break apps or data."
        case .protectedApplicationBundle:
            return "Application bundles in protected locations are blocked by default."
        case .volumeRoot:
            return "Volume roots are blocked. Select a specific file or folder inside the volume instead."
        case .ordinary, .directory, .package, .userCache:
            return nil
        }
    }

    public var confirmationWarning: String? {
        switch self {
        case .directory:
            return "This item is a folder and may contain many files."
        case .package:
            return "This item is a package. It appears as one file in Finder but contains many files inside."
        case .userCache:
            return "Cache folders are usually replaceable, but apps may still rely on their contents."
        case .ordinary,
             .userLibrary,
             .homeRoot,
             .systemRoot,
             .systemProtected,
             .protectedApplicationBundle,
             .volumeRoot,
             .permissionDenied,
             .missingURL:
            return nil
        }
    }
}
