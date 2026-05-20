import SwiftUI

@main
struct SpatiaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Spatia", id: "main") {
            MainWindowView()
                .environmentObject(model)
                .frame(minWidth: 1080, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Choose Folder...") {
                    model.chooseFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}
