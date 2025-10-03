import SwiftUI
import QuickLook
import AppKit

struct ZipTreeView: View {
    let entries: [ZipEntry]
    @EnvironmentObject private var appState: AppState
    @State private var currentPath: [ZipEntry] = []
    @State private var previewURL: URL?
    @State private var showPreview = false
    @FocusState private var isFocused: Bool
    var searchFieldFocused: FocusState<Bool>.Binding

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
            if !currentPath.isEmpty {
                breadcrumbView
            }

            fileListView
        }
        .quickLookPreview($previewURL)
        .contextMenu(forSelectionType: ZipEntry.self, menu: contextMenuContent, primaryAction: primaryActionHandler)
    }

    private var breadcrumbView: some View {
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

    private var fileListView: some View {
        ScrollViewReader { proxy in
            List(selection: Binding(
                get: { appState.selectedEntries },
                set: { newSelection in
                    appState.selectedEntries = newSelection
                }
            )) {
                ForEach(currentEntries, id: \.self) { entry in
                    FileRowContent(entry: entry)
                        .tag(entry)
                        .id(entry)
                        .gesture(
                            TapGesture()
                                .modifiers(.command)
                                .onEnded { _ in
                                    handleCommandClick(entry)
                                }
                        )
                        .gesture(
                            TapGesture()
                                .modifiers(.shift)
                                .onEnded { _ in
                                    handleShiftClick(entry)
                                }
                        )
                }
            }
            .listStyle(.sidebar)
            .focused($isFocused)
            .modifier(KeyboardShortcutsModifier(
                appState: appState,
                currentEntries: currentEntries,
                searchFieldFocused: searchFieldFocused,
                scrollProxy: proxy,
                onSpace: handleSpacebarPreview,
                onReturn: handleReturn,
                onDelete: handleDelete,
                onNavigateUp: navigateUp,
                onCommandDown: handleCommandDown,
                onArrowUp: { handleArrowNavigation(direction: .up, scrollProxy: proxy) },
                onArrowDown: { handleArrowNavigation(direction: .down, scrollProxy: proxy) },
                onShiftUp: { handleShiftArrow(direction: .up, scrollProxy: proxy) },
                onShiftDown: { handleShiftArrow(direction: .down, scrollProxy: proxy) },
                onCommandO: handleCommandO,
                onExtractSelected: handleExtractSelected,
                onExtractAll: handleExtractAll
            ))
        }
    }

    @ViewBuilder
    private func contextMenuContent(selection: Set<ZipEntry>) -> some View {
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
                if let url = appState.currentZipURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        } else if selection.count > 1 {
            Button("Extract \(selection.count) Items...") {
                showExtractionDialog(for: Array(selection))
            }
        }
    }

    private func primaryActionHandler(selection: Set<ZipEntry>) {
        if selection.count == 1, let entry = selection.first {
            if entry.isDirectory {
                navigateInto(entry)
            } else {
                openFile(entry)
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
                    _ = NSWorkspace.shared.open(tempFile)
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

    // MARK: - Keyboard Navigation Handlers

    private func handleArrowNavigation(direction: ArrowDirection, scrollProxy: ScrollViewProxy) {
        let focused = appState.focusedEntry ?? appState.selectedEntries.first

        guard !currentEntries.isEmpty else { return }

        if let focused = focused,
           let currentIndex = currentEntries.firstIndex(of: focused) {
            let newIndex: Int
            switch direction {
            case .up:
                newIndex = max(0, currentIndex - 1)
            case .down:
                newIndex = min(currentEntries.count - 1, currentIndex + 1)
            }

            if newIndex != currentIndex {
                let newEntry = currentEntries[newIndex]
                appState.selectSingle(newEntry)
                scrollProxy.scrollTo(newEntry, anchor: nil)
            }
        } else {
            // No selection, select first item
            let firstEntry = currentEntries[0]
            appState.selectSingle(firstEntry)
            scrollProxy.scrollTo(firstEntry, anchor: nil)
        }
    }

    private func handleShiftArrow(direction: ArrowDirection, scrollProxy: ScrollViewProxy) {
        guard !currentEntries.isEmpty else { return }

        let anchor = appState.lastSelectedEntry ?? appState.selectedEntries.first
        let focused = appState.focusedEntry ?? appState.selectedEntries.first

        if let anchor = anchor, let focused = focused,
           let focusedIndex = currentEntries.firstIndex(of: focused) {
            let newIndex: Int
            switch direction {
            case .up:
                newIndex = max(0, focusedIndex - 1)
            case .down:
                newIndex = min(currentEntries.count - 1, focusedIndex + 1)
            }

            if newIndex != focusedIndex {
                let newEntry = currentEntries[newIndex]
                appState.focusedEntry = newEntry
                appState.selectedEntries.removeAll()
                appState.selectRange(from: anchor, to: newEntry, in: currentEntries)
                scrollProxy.scrollTo(newEntry, anchor: nil)
            }
        } else if let first = currentEntries.first {
            appState.selectSingle(first)
            scrollProxy.scrollTo(first, anchor: nil)
        }
    }

    private func handleCommandClick(_ entry: ZipEntry) {
        appState.toggleSelection(entry)
        appState.lastSelectedEntry = entry
        appState.focusedEntry = entry
    }

    private func handleShiftClick(_ entry: ZipEntry) {
        if let lastSelected = appState.lastSelectedEntry {
            appState.selectRange(from: lastSelected, to: entry, in: currentEntries)
        } else {
            appState.selectSingle(entry)
        }
        appState.focusedEntry = entry
    }

    private func handleReturn() {
        if appState.selectedEntries.count == 1, let entry = appState.selectedEntries.first {
            if entry.isDirectory {
                navigateInto(entry)
            } else {
                openFile(entry)
            }
        }
    }

    private func handleCommandO() {
        for entry in appState.selectedEntries {
            if !entry.isDirectory {
                openFile(entry)
            }
        }
    }

    private func handleDelete() {
        if !appState.selectedEntries.isEmpty {
            appState.clearSelection()
        } else if !currentPath.isEmpty {
            navigateUp()
        }
    }

    private func handleCommandDown() {
        if appState.selectedEntries.count == 1,
           let entry = appState.selectedEntries.first,
           entry.isDirectory {
            navigateInto(entry)
        }
    }

    private func handleExtractSelected() {
        guard !appState.selectedEntries.isEmpty else { return }
        showExtractionDialog(for: Array(appState.selectedEntries))
    }

    private func handleExtractAll() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Extract All"

        if panel.runModal() == .OK, let url = panel.url {
            appState.extractAll(to: url)
        }
    }

    enum ArrowDirection {
        case up
        case down
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
    @FocusState var searchFocus: Bool

    return ZipTreeView(entries: [
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
    ], searchFieldFocused: $searchFocus)
    .environmentObject(AppState())
}

// MARK: - Keyboard Shortcuts Modifier

struct KeyboardShortcutsModifier: ViewModifier {
    @ObservedObject var appState: AppState
    let currentEntries: [ZipEntry]
    let searchFieldFocused: FocusState<Bool>.Binding
    let scrollProxy: ScrollViewProxy
    let onSpace: () -> Void
    let onReturn: () -> Void
    let onDelete: () -> Void
    let onNavigateUp: () -> Void
    let onCommandDown: () -> Void
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void
    let onShiftUp: () -> Void
    let onShiftDown: () -> Void
    let onCommandO: () -> Void
    let onExtractSelected: () -> Void
    let onExtractAll: () -> Void

    func body(content: Content) -> some View {
        content
            .onKeyPress(.space) {
                onSpace()
                return .handled
            }
            .onKeyPress(.return) {
                onReturn()
                return .handled
            }
            .onKeyPress(.escape) {
                appState.clearSelection()
                return .handled
            }
            .onKeyPress(.deleteForward) {
                onDelete()
                return .handled
            }
            .onKeyPress(.delete) {
                onDelete()
                return .handled
            }
            .onKeyPress(keys: [.upArrow]) { press in
                if press.modifiers.contains(.command) {
                    onNavigateUp()
                    return .handled
                } else if press.modifiers.contains(.shift) {
                    onShiftUp()
                    return .handled
                } else {
                    onArrowUp()
                    return .handled
                }
            }
            .onKeyPress(keys: [.downArrow]) { press in
                if press.modifiers.contains(.command) {
                    onCommandDown()
                    return .handled
                } else if press.modifiers.contains(.shift) {
                    onShiftDown()
                    return .handled
                } else {
                    onArrowDown()
                    return .handled
                }
            }
            .onKeyPress(keys: [.init("a")]) { press in
                if press.modifiers.contains(.command) {
                    appState.selectAll(from: currentEntries)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: [.init("o")]) { press in
                if press.modifiers.contains(.command) {
                    onCommandO()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: [.init("c")]) { press in
                if press.modifiers.contains(.command) {
                    appState.copySelectedPaths()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: [.init("e")]) { press in
                if press.modifiers.contains(.command) && press.modifiers.contains(.shift) {
                    onExtractAll()
                    return .handled
                } else if press.modifiers.contains(.command) {
                    onExtractSelected()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: [.init("f")]) { press in
                if press.modifiers.contains(.command) {
                    searchFieldFocused.wrappedValue = true
                    return .handled
                }
                return .ignored
            }
    }
}
