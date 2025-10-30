import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    let fileURL: URL
    @StateObject private var appState = AppState()
    @State private var showingDestinationPicker = false
    @State private var selectedDestinationURL: URL?
    @State private var isTargeted = false
    @FocusState private var searchFieldFocused: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 0) {
            // Left pane - always visible
            VStack {
                if appState.entries.isEmpty {
                    emptyStateView
                } else {
                    ZipTreeView(entries: appState.filteredEntries, searchFieldFocused: $searchFieldFocused)
                        .searchable(text: $appState.searchQuery, prompt: "Search files and folders")
                        .environmentObject(appState)
                }
            }
            .frame(maxWidth: .infinity)

            // Right pane - only visible when file/folder selected
            if !appState.selectedEntries.isEmpty {
                Divider()

                detailView
                    .frame(width: 350)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.selectedEntries.isEmpty)
        .toolbar {
            toolbarContent
        }
        .fileDialogURLSelection($selectedDestinationURL, $showingDestinationPicker) { url in
            if appState.selectedEntries.isEmpty {
                appState.extractAll(to: url)
            } else {
                appState.extractSelected(to: url)
            }
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred")
        }
        .overlay {
            if appState.isExtracting {
                extractionOverlay
            } else if appState.isLoading {
                loadingOverlay
            }
        }
        .onAppear {
            // Load the zip file when the view appears
            appState.openZipFile(at: fileURL)
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
        .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Loading Zip File...")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Drop another zip file here to open it in a new window")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailView: some View {
        Group {
            if let firstSelected = appState.selectedEntries.first, appState.selectedEntries.count == 1 {
                FileDetailView(entry: firstSelected, appState: appState)
            } else if appState.selectedEntries.count > 1 {
                multipleSelectionView
            }
        }
    }

    private var multipleSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("\(appState.selectedEntries.count) items selected")
                .font(.title2)
                .fontWeight(.semibold)

            let totalSize = appState.selectedEntries.reduce(0) { $0 + $1.uncompressedSize }
            Text("Total size: \(ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file))")
                .foregroundColor(.secondary)

            Button(action: {
                showingDestinationPicker = true
            }) {
                Label("Extract Selected", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var zipInfoView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            if let url = appState.currentZipURL {
                Text(url.lastPathComponent)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(url.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let totalItems = countAllItems(appState.entries)
            Text("\(totalItems) items")
                .foregroundColor(.secondary)

            Button(action: {
                showingDestinationPicker = true
            }) {
                Label("Extract All", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: appState.loadingProgress) {
                    Text("Loading Archive...")
                        .font(.headline)
                }
                .progressViewStyle(.linear)
                .frame(width: 300)

                if appState.loadedEntryCount > 0 {
                    Text("\(appState.loadedEntryCount) entries loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(Material.regular)
            .cornerRadius(12)
        }
    }

    private var extractionOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: appState.extractionProgress) {
                    Text("Extracting...")
                        .font(.headline)
                }
                .progressViewStyle(.linear)
                .frame(width: 300)

                if !appState.extractionFileName.isEmpty {
                    Text(appState.extractionFileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 300)
                }
            }
            .padding(24)
            .background(Material.regular)
            .cornerRadius(12)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                showingDestinationPicker = true
            }) {
                Label("Extract", systemImage: "arrow.down.circle")
            }
            .disabled(appState.selectedEntries.isEmpty && appState.entries.isEmpty)
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

    private func countAllItems(_ entries: [ZipEntry]) -> Int {
        var count = entries.count
        for entry in entries {
            count += countAllItems(entry.children)
        }
        return count
    }
}

extension View {
    func fileDialogURLSelection(_ url: Binding<URL?>, _ isPresented: Binding<Bool>, onSelection: @escaping (URL) -> Void) -> some View {
        self.sheet(isPresented: isPresented) {
            FileDestinationPicker(selectedURL: url, onSelection: onSelection)
        }
    }
}

struct FileDestinationPicker: View {
    @Binding var selectedURL: URL?
    let onSelection: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Destination")
                .font(.headline)

            Button("Choose Folder...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.canCreateDirectories = true

                if panel.runModal() == .OK {
                    selectedURL = panel.url
                }
            }
            .buttonStyle(.bordered)

            if let destination = selectedURL {
                Text(destination.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Extract") {
                    if let url = selectedURL {
                        dismiss()
                        onSelection(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedURL == nil)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

struct FileDetailView: View {
    let entry: ZipEntry
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: entry.icon)
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    VStack(alignment: .leading) {
                        Text(entry.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(entry.fileType)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Size", value: entry.formattedSize)
                    DetailRow(label: "Compressed", value: entry.formattedCompressedSize)
                    DetailRow(label: "Compression Ratio", value: String(format: "%.1f%%", entry.compressionRatio * 100))

                    if let date = entry.modificationDate {
                        DetailRow(label: "Modified", value: date.formatted())
                    }

                    DetailRow(label: "Path", value: entry.path)
                }
                .padding()

                Spacer()
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .textSelection(.enabled)
        }
    }
}
