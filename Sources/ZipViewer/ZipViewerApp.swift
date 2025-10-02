import SwiftUI

@main
struct ZipViewerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Zip File...") {
                    NotificationCenter.default.post(name: .openZipFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let openZipFile = Notification.Name("openZipFile")
}
