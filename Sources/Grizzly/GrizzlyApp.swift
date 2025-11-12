import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

@main
struct GrizzlyApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State private var pendingURLs: [URL] = []

    init() {
        // Set up a simple callback for the delegate to signal when files should be opened
    }

    var body: some Scene {
        #if os(macOS)
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
        #else
        WindowGroup {
            IOSContentView()
        }
        #endif
    }
}

#if os(macOS)
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
    @Environment(\.openWindow) private var openWindow
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            // Background layer for drop highlight
            (isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
                .ignoresSafeArea()

            // Content
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 600, minHeight: 400)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "zip" else {
                return
            }

            // Open the dropped file in a new window
            DispatchQueue.main.async {
                openWindow(value: url)
            }
        }

        return true
    }
}
#endif

// iOS-specific content view
#if os(iOS)
struct IOSContentView: View {
    @State private var selectedZipURL: URL?
    @State private var showingFilePicker = false

    var body: some View {
        NavigationView {
            Group {
                if let zipURL = selectedZipURL {
                    ContentView(fileURL: zipURL)
                } else {
                    IOSEmptyView(showingFilePicker: $showingFilePicker)
                }
            }
            .navigationTitle("Grizzly")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        Label("Open", systemImage: "folder")
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            FilePickerIOS(
                selectedURL: $selectedZipURL,
                allowedTypes: [.zip],
                canChooseDirectories: false
            ) { url in
                if let url = url {
                    selectedZipURL = url
                }
            }
        }
        .onOpenURL { url in
            // Handle "Open With" on iOS - set the URL to open the zip file
            if url.pathExtension.lowercased() == "zip" {
                selectedZipURL = url
            }
        }
    }
}

struct IOSEmptyView: View {
    @Binding var showingFilePicker: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Zip File Opened")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the folder icon to open a zip file")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: {
                showingFilePicker = true
            }) {
                Label("Open Zip File", systemImage: "folder")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif

class ZipFileOpener {
    static let shared = ZipFileOpener()
    var openWindow: ((URL) -> Void)?

    func openZipFile() {
        #if os(macOS)
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
        #endif
    }
}
