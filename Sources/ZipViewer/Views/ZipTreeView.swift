import SwiftUI
import QuickLook

struct ZipTreeView: View {
    let entries: [ZipEntry]
    @EnvironmentObject private var appState: AppState
    @State private var currentPath: [ZipEntry] = []
    @State private var previewURL: URL?
    @State private var showPreview = false
    @FocusState private var isFocused: Bool

    private var currentEntries: [ZipEntry] {
        let baseEntries: [ZipEntry]
        if currentPath.isEmpty {
            baseEntries = entries
        } else {
            baseEntries = currentPath.last?.children ?? []
        }

        // Apply search filter
        if appState.searchQuery.isEmpty {
            return baseEntries
        } else {
            return baseEntries.filter { entry in
                entry.name.localizedCaseInsensitiveContains(appState.searchQuery)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb navigation
            if !currentPath.isEmpty {
                HStack {
                    Button(action: navigateUp) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.borderless)

                    Divider()
                        .frame(height: 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(currentPath.enumerated()), id: \.element.id) { index, entry in
                                Button(action: {
                                    navigateTo(index: index)
                                }) {
                                    Text(entry.name)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)

                                if index < currentPath.count - 1 {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
            }

            List(selection: Binding(
                get: { appState.selectedEntries },
                set: { newSelection in
                    appState.selectedEntries = newSelection
                }
            )) {
                ForEach(currentEntries, id: \.self) { entry in
                    FileRowContent(entry: entry)
                        .tag(entry)
                }
            }
            .listStyle(.sidebar)
            .onKeyPress(.space) {
                handleSpacebarPreview()
                return .handled
            }
        }
        .quickLookPreview($previewURL)
        .contextMenu(forSelectionType: ZipEntry.self) { selection in
            if selection.count == 1, let entry = selection.first {
                Button("Extract...") {
                    showExtractionDialog(for: [entry])
                }

                if !entry.isDirectory {
                    Button("Quick Look") {
                        handleSpacebarPreview()
                    }
                }

                Divider()

                Button("Show in Finder") {
                    // This would show the zip file location
                    if let url = appState.currentZipURL {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            } else if selection.count > 1 {
                Button("Extract \(selection.count) Items...") {
                    showExtractionDialog(for: Array(selection))
                }
            }
        } primaryAction: { selection in
            if selection.count == 1, let entry = selection.first {
                if entry.isDirectory {
                    navigateInto(entry)
                } else {
                    openFile(entry)
                }
            }
        }
    }

    private func navigateInto(_ entry: ZipEntry) {
        currentPath.append(entry)
        appState.clearSelection()
    }

    private func navigateUp() {
        if !currentPath.isEmpty {
            currentPath.removeLast()
            appState.clearSelection()
        }
    }

    private func navigateTo(index: Int) {
        if index < currentPath.count {
            currentPath.removeSubrange((index + 1)..<currentPath.count)
            appState.clearSelection()
        }
    }

    private func openFile(_ entry: ZipEntry) {
        Task {
            do {
                let data = try await appState.getPreviewData(for: entry)

                // Create temp file
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent(entry.name)

                try data.write(to: tempFile)

                await MainActor.run {
                    // Open with default application
                    NSWorkspace.shared.open(tempFile)
                }
            } catch {
                await MainActor.run {
                    appState.errorMessage = "Failed to open file: \(error.localizedDescription)"
                    appState.showError = true
                }
            }
        }
    }

    private func handleSpacebarPreview() {
        guard let firstSelected = appState.selectedEntries.first,
              appState.selectedEntries.count == 1,
              !firstSelected.isDirectory else {
            return
        }

        Task {
            do {
                let data = try await appState.getPreviewData(for: firstSelected)

                // Create temp file for preview
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent(firstSelected.name)

                try data.write(to: tempFile)

                await MainActor.run {
                    previewURL = tempFile
                }
            } catch {
                await MainActor.run {
                    appState.errorMessage = "Failed to preview file: \(error.localizedDescription)"
                    appState.showError = true
                }
            }
        }
    }

    private func showExtractionDialog(for entries: [ZipEntry]) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Extract"

        if panel.runModal() == .OK, let url = panel.url {
            for entry in entries {
                appState.extractEntry(entry, to: url)
            }
        }
    }
}

struct FileRowContent: View {
    let entry: ZipEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.icon)
                .foregroundColor(entry.isDirectory ? .blue : .secondary)
                .frame(width: 20)

            Text(entry.name)
                .lineLimit(1)

            Spacer()

            if !entry.isDirectory {
                Text(entry.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ZipTreeView(entries: [
        ZipEntry(
            path: "folder1/",
            name: "folder1",
            isDirectory: true,
            uncompressedSize: 0,
            compressedSize: 0,
            modificationDate: Date(),
            children: [
                ZipEntry(
                    path: "folder1/file1.txt",
                    name: "file1.txt",
                    isDirectory: false,
                    uncompressedSize: 1024,
                    compressedSize: 512,
                    modificationDate: Date()
                )
            ]
        )
    ])
    .environmentObject(AppState())
}
