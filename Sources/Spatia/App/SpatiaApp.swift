import SwiftUI

@main
struct SpatiaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Spatia", id: "main") {
            MainWindowView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 640)
        }
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
