import SwiftUI

@main
struct SpatiaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Spatia", id: "main") {
            MainWindowView()
                .environmentObject(model)
                .frame(minWidth: 1280, minHeight: 700)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Choose Folder...") {
                    model.chooseFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("Scan") {
                Button("Rescan") {
                    model.rescanCurrentSource()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.currentScanURL == nil || model.isScanning)

                Button("Cancel Scan") {
                    model.cancelScan()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!model.isScanning)
            }

            CommandMenu("Find") {
                Button("Find") {
                    model.focusSearch()
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button("Clear Search") {
                    model.clearSearch()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(model.searchQuery.isEmpty)
            }

            CommandMenu("Item") {
                Button("Enter Selected Item") {
                    model.enterSelectedDirectory()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!model.canEnterSelectedContainer)

                Button("Up") {
                    model.goUp()
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])
                .disabled(model.displayRoot?.parentID == nil)

                Divider()

                Button("Quick Look") {
                    model.quickLookSelected()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(!model.canQuickLookSelected)

                Button("Expand Package") {
                    Task {
                        await model.expandSelectedPackage()
                    }
                }
                .disabled(!model.canExpandSelectedPackage)

                Button("Reveal in Finder") {
                    model.revealSelectedInFinder()
                }
                .disabled(!model.canRevealSelected)

                Button("Copy Path") {
                    model.copySelectedPath()
                }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(!model.canCopySelectedPath)

                Divider()

                Button("Move to Trash") {
                    Task {
                        await model.moveSelectedItemToTrash()
                    }
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(!model.canMoveSelectedToTrash)
            }
        }
    }
}
