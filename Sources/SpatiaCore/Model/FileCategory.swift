import Foundation

public enum FileCategory: String, Hashable, Sendable {
    case video
    case image
    case audio
    case archive
    case appPackage
    case document
    case source
    case cache
    case system
    case other
}

public enum FileCategoryClassifier {
    public static func category(for node: FileNode) -> FileCategory {
        category(
            name: node.name,
            path: node.url?.path,
            kind: node.kind,
            typeIdentifier: node.typeIdentifier,
            flags: node.flags
        )
    }

    public static func category(
        name: String,
        path: String?,
        kind: NodeKind,
        typeIdentifier: String?,
        flags: NodeFlags = []
    ) -> FileCategory {
        let url = path.map { URL(fileURLWithPath: $0, isDirectory: kind == .directory || kind == .package) }
        let pathRiskPolicy = PathRiskPolicy()

        if pathRiskPolicy.isSystemCategory(url: url, flags: flags) {
            return .system
        }

        if pathRiskPolicy.isCacheCategory(url: url, name: name) {
            return .cache
        }

        let lowercasedName = name.lowercased()
        let ext = (lowercasedName as NSString).pathExtension
        let uti = typeIdentifier?.lowercased() ?? ""

        if kind == .package || lowercasedName.hasSuffix(".app") {
            return .appPackage
        }

        if matches(ext: ext, uti: uti, extensions: videoExtensions, utiHints: ["movie", "video", "mpeg-4"]) {
            return .video
        }

        if matches(ext: ext, uti: uti, extensions: imageExtensions, utiHints: ["image", "jpeg", "png", "heic"]) {
            return .image
        }

        if matches(ext: ext, uti: uti, extensions: audioExtensions, utiHints: ["audio", "mp3", "mpeg-4-audio"]) {
            return .audio
        }

        if matches(ext: ext, uti: uti, extensions: archiveExtensions, utiHints: ["archive", "zip", "disk-image", "gzip"]) {
            return .archive
        }

        if sourceExtensions.contains(ext) || uti.contains("source") || uti.contains("script") {
            return .source
        }

        if documentExtensions.contains(ext)
            || uti.contains("pdf")
            || uti.contains("text")
            || uti.contains("document")
            || uti.contains("presentation")
            || uti.contains("spreadsheet") {
            return .document
        }

        return .other
    }

    private static func matches(
        ext: String,
        uti: String,
        extensions: Set<String>,
        utiHints: [String]
    ) -> Bool {
        extensions.contains(ext) || utiHints.contains { uti.contains($0) }
    }

    private static let videoExtensions: Set<String> = [
        "avi", "m2ts", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "webm"
    ]

    private static let imageExtensions: Set<String> = [
        "avif", "gif", "heic", "heif", "jpeg", "jpg", "png", "raw", "tif", "tiff", "webp"
    ]

    private static let audioExtensions: Set<String> = [
        "aac", "aiff", "alac", "flac", "m4a", "mp3", "ogg", "wav"
    ]

    private static let archiveExtensions: Set<String> = [
        "7z", "bz2", "dmg", "gz", "pkg", "rar", "tar", "tgz", "xz", "zip"
    ]

    private static let sourceExtensions: Set<String> = [
        "c", "cc", "cpp", "css", "go", "h", "hpp", "html", "java", "js", "json", "kt", "m", "mm",
        "php", "py", "rb", "rs", "sh", "swift", "ts", "tsx", "xml", "yaml", "yml"
    ]

    private static let documentExtensions: Set<String> = [
        "csv", "doc", "docx", "key", "md", "numbers", "pages", "pdf", "ppt", "pptx", "rtf", "txt", "xls", "xlsx"
    ]
}
