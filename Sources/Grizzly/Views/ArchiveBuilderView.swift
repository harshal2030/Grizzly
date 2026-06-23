import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit

/// The "New Archive" staging window: gather files/folders, choose compression,
/// then create a `.zip` via a native save panel.
struct ArchiveBuilderView: View {
    @StateObject private var state = ArchiveBuilderState()
    @State private var isTargeted = false
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            itemList
            Divider()
            footer
        }
        .frame(minWidth: 480, minHeight: 420)
        .overlay {
            if state.isCompressing {
                compressionOverlay
            }
        }
        .alert("Couldn’t Create Archive", isPresented: $state.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: state.didCreateArchive) { _, created in
            // Once the zip is written, close the staging window and clear it.
            if created {
                dismissWindow(id: archiveBuilderWindowID)
                state.reset()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("New Archive")
                    .font(.headline)
                Text(itemSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private var itemSummary: String {
        if state.items.isEmpty { return "No items yet" }
        return state.items.count == 1 ? "1 item" : "\(state.items.count) items"
    }

    // MARK: - Item list

    private var itemList: some View {
        ZStack {
            if isTargeted {
                Color.accentColor.opacity(0.1)
            }

            if state.items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(state.items) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .foregroundColor(item.isDirectory ? .blue : .secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .lineLimit(1)
                                Text(item.url.deletingLastPathComponent().path)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Text(item.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button {
                                state.remove(item)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Remove from archive")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.zipper")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("Drag files and folders here")
                .font(.title3)
                .fontWeight(.semibold)

            Text("or use “Add Files…” below to choose items to compress")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                addFiles()
            } label: {
                Label("Add Files…", systemImage: "plus")
            }

            if !state.items.isEmpty {
                Button(role: .destructive) {
                    state.removeAll()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }

            Spacer()

            Button {
                createArchive()
            } label: {
                Label("Create Archive…", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(state.items.isEmpty)
        }
        .padding()
    }

    // MARK: - Compression overlay

    private var compressionOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: state.progress) {
                    Text("Creating Archive…")
                        .font(.headline)
                }
                .progressViewStyle(.linear)
                .frame(width: 300)

                if !state.currentFileName.isEmpty {
                    Text(state.currentFileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 300)
                }

                Button("Cancel") {
                    state.cancel()
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .background(Material.regular)
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose files and folders to compress"

        if panel.runModal() == .OK {
            state.addURLs(panel.urls)
        }
    }

    private func createArchive() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = state.defaultArchiveName
        panel.title = "Save Archive"
        panel.prompt = "Create"

        if panel.runModal() == .OK, let url = panel.url {
            state.createArchive(to: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let lock = NSLock()
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    lock.lock()
                    urls.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            state.addURLs(urls)
        }

        return true
    }
}

#endif
