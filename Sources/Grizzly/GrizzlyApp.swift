import SwiftUI
import AppKit

@main
struct GrizzlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Grizzly") {
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

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.pathExtension.lowercased() == "zip" {
                NotificationCenter.default.post(name: .openZipFileWithURL, object: url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let openZipFile = Notification.Name("openZipFile")
    static let openZipFileWithURL = Notification.Name("openZipFileWithURL")
}
