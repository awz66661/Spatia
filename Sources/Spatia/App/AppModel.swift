import Foundation
import SpatiaCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var result: ScanResult?
    @Published var selectedID: NodeID?
    @Published var displayRootID: NodeID?
    @Published var isScanning = false
    @Published var statusText = "Choose a folder to scan."

    private var scanTask: Task<Void, Never>?

    var snapshot: FileTreeSnapshot? {
        result?.snapshot
    }

    var displayRoot: FileNode? {
        guard let snapshot else { return nil }
        if let displayRootID, let node = snapshot[displayRootID] {
            return node
        }
        return snapshot.root
    }

    var selectedNode: FileNode? {
        guard let selectedID else { return nil }
        return snapshot?[selectedID]
    }

    var visibleInputs: [TreemapInput] {
        guard let snapshot, let root = displayRoot else { return [] }
        let children = snapshot.children(of: root.id)
            .filter { $0.allocatedSize > 0 }
            .sorted { $0.allocatedSize > $1.allocatedSize }

        if children.isEmpty, root.allocatedSize > 0 {
            return [
                TreemapInput(
                    nodeID: root.id,
                    label: root.name,
                    size: root.allocatedSize,
                    kind: root.kind,
                    flags: root.flags
                )
            ]
        }

        return children.map {
            TreemapInput(
                nodeID: $0.id,
                label: $0.name,
                size: $0.allocatedSize,
                kind: $0.kind,
                flags: $0.flags
            )
        }
    }

    var breadcrumb: [FileNode] {
        guard let snapshot, let displayRoot else { return [] }
        return snapshot.breadcrumb(for: displayRoot.id)
    }

    func scanDownloads() {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
        scan(downloads)
    }

    func scanHome() {
        scan(FileManager.default.homeDirectoryForCurrentUser)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        scan(url)
    }

    func scan(_ url: URL) {
        scanTask?.cancel()
        isScanning = true
        selectedID = nil
        displayRootID = nil
        statusText = "Scanning \(url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent)..."

        scanTask = Task {
            let options = ScanOptions(expandPackages: false, includeHiddenFiles: true)
            let scanner = FileScanner(options: options)
            let scanResult = await Task.detached(priority: .userInitiated) {
                scanner.scan(root: url)
            }.value

            guard !Task.isCancelled else { return }

            result = scanResult
            displayRootID = scanResult.snapshot.rootID
            isScanning = false
            statusText = "Scanned \(scanResult.summary.fileCount) files, \(ByteCount.string(scanResult.summary.allocatedBytes))."
        }
    }

    func select(_ id: NodeID?) {
        selectedID = id == syntheticOtherNodeID ? nil : id
    }

    func enterSelectedDirectory() {
        guard let selectedID else { return }
        enterDirectory(selectedID)
    }

    func enterDirectory(_ id: NodeID) {
        guard id != syntheticOtherNodeID, let node = snapshot?[id], !node.children.isEmpty else { return }
        guard node.kind == .directory || node.kind == .package || node.kind == .volume else { return }
        displayRootID = node.id
        selectedID = nil
    }

    func goUp() {
        guard let displayRoot, let parentID = displayRoot.parentID else { return }
        displayRootID = parentID
        selectedID = nil
    }
}
