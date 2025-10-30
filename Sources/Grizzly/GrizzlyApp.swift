import SwiftUI
import AppKit

@main
struct GrizzlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var pendingURLs: [URL] = []

    init() {
        // Set up a simple callback for the delegate to signal when files should be opened
    }

    var body: some Scene {
        WindowGroup(for: URL.self) { $fileURL in
            WindowContentView(fileURL: $fileURL, appDelegate: appDelegate)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Zip File...") {
                    ZipFileOpener.shared.openZipFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
        .defaultSize(width: 800, height: 600)
    }
}

struct WindowContentView: View {
    @Binding var fileURL: URL?
    @Environment(\.openWindow) private var openWindow
    let appDelegate: AppDelegate

    var body: some View {
        Group {
            if let fileURL = fileURL {
                ContentView(fileURL: fileURL)
            } else {
                EmptyDocumentView()
            }
        }
        .background(WindowAccessor(fileURL: fileURL, appDelegate: appDelegate))
        .onAppear {
            // Set up the window opener callback
            ZipFileOpener.shared.openWindow = { url in
                openWindow(value: url)
            }
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let fileURL: URL?
    let appDelegate: AppDelegate

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            // Process pending files when the view is added to window
            if !appDelegate.pendingFilesToOpen.isEmpty && fileURL == nil,
               let window = view.window {

                let pendingURLs = appDelegate.pendingFilesToOpen
                appDelegate.pendingFilesToOpen.removeAll()

                // Open all pending files
                for url in pendingURLs {
                    ZipFileOpener.shared.openWindow?(url)
                }

                // Close this empty window after new windows open
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if NSApplication.shared.windows.count > 1 {
                        window.close()
                    }
                }
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class ZipFileOpener {
    static let shared = ZipFileOpener()
    var openWindow: ((URL) -> Void)?

    func openZipFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.zip]

        if panel.runModal() == .OK {
            for url in panel.urls {
                openWindow?(url)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var pendingFilesToOpen: [URL] = []
    weak var temporaryWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure at least one window opens to process pending files
        if NSApplication.shared.windows.isEmpty {
            // Trigger creation of an empty window
            NSApp.sendAction(Selector(("newDocument:")), to: nil, from: nil)
            // Store reference to this window so we can close it later
            DispatchQueue.main.async {
                self.temporaryWindow = NSApplication.shared.windows.first
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.pathExtension.lowercased() == "zip" {
                // Store files to be opened by the first window that appears
                pendingFilesToOpen.append(url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

struct EmptyDocumentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Zip File Opened")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Use Cmd+O to open a zip file or drop one here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
