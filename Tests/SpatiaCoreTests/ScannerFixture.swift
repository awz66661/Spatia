import Foundation
import SpatiaCore
import XCTest

final class ScannerFixture {
    let rootURL: URL

    private let fileManager = FileManager.default

    init(name: String = #function) throws {
        let safeName = name
            .replacingOccurrences(of: "(", with: "-")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "-")
        rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("SpatiaScannerTests", isDirectory: true)
            .appendingPathComponent("\(safeName)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func tearDown() throws {
        if fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.removeItem(at: rootURL)
        }
    }

    @discardableResult
    func directory(_ relativePath: String) throws -> URL {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    func file(_ relativePath: String, bytes: Int) throws -> URL {
        let url = rootURL.appendingPathComponent(relativePath)
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        try Data(repeating: 0x2A, count: bytes).write(to: url, options: .atomic)
        return url
    }

    @discardableResult
    func symlink(_ relativePath: String, destination: URL) throws -> URL {
        let url = rootURL.appendingPathComponent(relativePath)
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: url, withDestinationURL: destination)
        return url
    }

    func child(named name: String, in node: FileNode, snapshot: FileTreeSnapshot) -> FileNode? {
        snapshot.children(of: node.id).first { $0.name == name }
    }
}
