import AppKit
import Foundation
import QuickLookUI

enum MacActions {
    @MainActor
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @MainActor
    static func copyPath(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    @MainActor
    static func quickLook(_ url: URL) -> QuickLookResult {
        QuickLookCoordinator.shared.preview(url)
    }

    @MainActor
    static func confirmMoveToTrash(_ confirmation: TrashConfirmation) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Move \"\(confirmation.name)\" to Trash?"

        var details = [
            "Path: \(confirmation.path)",
            "Size: \(confirmation.sizeText)",
            "Items: \(confirmation.itemCount)"
        ]
        details.append(contentsOf: confirmation.warnings)
        alert.informativeText = details.joined(separator: "\n")
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }

    static func moveToTrash(_ url: URL) async -> TrashActionResult {
        await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle([url]) { newURLs, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.code == NSUserCancelledError {
                        continuation.resume(returning: .cancelled)
                    } else if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteNoPermissionError {
                        continuation.resume(returning: .permissionDenied(error.localizedDescription))
                    } else if newURLs[url] != nil {
                        continuation.resume(returning: .partialFailure(error.localizedDescription))
                    } else {
                        continuation.resume(returning: .failed(error.localizedDescription))
                    }
                    return
                }

                if let resultingURL = newURLs[url] {
                    continuation.resume(returning: .moved(resultingURL: resultingURL))
                } else {
                    continuation.resume(returning: .failed("The item was not moved to Trash."))
                }
            }
        }
    }
}

struct TrashConfirmation: Hashable {
    var name: String
    var path: String
    var sizeText: String
    var itemCount: Int
    var warnings: [String]
}

enum TrashActionResult: Equatable {
    case moved(resultingURL: URL?)
    case cancelled
    case permissionDenied(String)
    case partialFailure(String)
    case failed(String)
}

enum QuickLookResult: Equatable {
    case shown
    case unavailable
}

@MainActor
private final class QuickLookCoordinator: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookCoordinator()

    private var previewURL: URL?

    func preview(_ url: URL) -> QuickLookResult {
        previewURL = url

        guard let panel = QLPreviewPanel.shared() else {
            return .unavailable
        }

        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
        return .shown
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL as NSURL?
    }
}
