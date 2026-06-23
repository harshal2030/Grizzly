import Foundation
import SwiftUI

#if os(macOS)

/// View model backing the "New Archive" staging window. Holds the list of items
/// the user has gathered, the compression choice, and drives archive creation
/// off the main thread while reporting progress.
@MainActor
final class ArchiveBuilderState: ObservableObject {
    struct Item: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let name: String
        let isDirectory: Bool
        let size: Int64?

        var icon: String { isDirectory ? "folder.fill" : "doc.fill" }

        var formattedSize: String {
            guard let size else { return "Folder" }
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }

    @Published var items: [Item] = []

    @Published var isCompressing = false
    @Published var progress: Double = 0
    @Published var currentFileName = ""

    @Published var errorMessage: String?
    @Published var showError = false

    /// Flips to `true` once an archive has been written successfully, so the
    /// window can close itself and reset.
    @Published var didCreateArchive = false

    private let manager = ZipArchiveManager()
    private var activeProgress: Progress?

    /// Pre-filled name for the save panel: `<name>.zip` for a single item,
    /// otherwise `Archive.zip` (matching Finder).
    var defaultArchiveName: String {
        if items.count == 1 {
            return items[0].name + ".zip"
        }
        return "Archive.zip"
    }

    // MARK: - Staging

    func addURLs(_ urls: [URL]) {
        let existing = Set(items.map { $0.url.standardizedFileURL })
        for url in urls {
            let std = url.standardizedFileURL
            guard !existing.contains(std) else { continue }

            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: std.path, isDirectory: &isDir) else { continue }

            let size: Int64? = isDir.boolValue
                ? nil
                : (try? std.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) }

            items.append(Item(url: std,
                              name: std.lastPathComponent,
                              isDirectory: isDir.boolValue,
                              size: size))
        }
    }

    func remove(_ item: Item) {
        items.removeAll { $0.id == item.id }
    }

    func removeAll() {
        items.removeAll()
    }

    /// Clears the staging area back to its initial empty state.
    func reset() {
        items.removeAll()
        isCompressing = false
        progress = 0
        currentFileName = ""
        activeProgress = nil
        errorMessage = nil
        showError = false
        didCreateArchive = false
    }

    // MARK: - Compression

    func cancel() {
        activeProgress?.cancel()
    }

    func createArchive(to destinationURL: URL) {
        guard !items.isEmpty else { return }

        let sources = items.map { $0.url }
        let progressObject = Progress()

        activeProgress = progressObject
        isCompressing = true
        progress = 0
        currentFileName = ""

        let manager = manager
        Task.detached(priority: .userInitiated) {
            do {
                try manager.createArchive(from: sources,
                                          to: destinationURL,
                                          overallProgress: progressObject) { fraction, name in
                    Task { @MainActor in
                        self.progress = fraction
                        self.currentFileName = name
                    }
                }

                await MainActor.run {
                    self.isCompressing = false
                    self.progress = 0
                    self.currentFileName = ""
                    self.activeProgress = nil
                    self.didCreateArchive = true
                }
            } catch ZipArchiveManager.ZipError.cancelled {
                await MainActor.run {
                    self.isCompressing = false
                    self.progress = 0
                    self.currentFileName = ""
                    self.activeProgress = nil
                }
            } catch {
                await MainActor.run {
                    self.isCompressing = false
                    self.progress = 0
                    self.currentFileName = ""
                    self.activeProgress = nil
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}

#endif
