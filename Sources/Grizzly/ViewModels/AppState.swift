import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var entries: [ZipEntry] = []
    @Published var selectedEntries: Set<ZipEntry> = []
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var currentZipURL: URL?
    @Published var extractionProgress: Double = 0
    @Published var isExtracting: Bool = false
    @Published var extractionFileName: String = ""
    @Published var loadingProgress: Double = 0
    @Published var loadedEntryCount: Int = 0
    @Published var focusedEntry: ZipEntry?
    @Published var lastSelectedEntry: ZipEntry?

    private let archiveManager = ZipArchiveManager()
    private var securityScopedURL: URL?

    var filteredEntries: [ZipEntry] {
        if searchQuery.isEmpty {
            return entries
        }
        return filterEntriesRecursively(entries, query: searchQuery.lowercased())
    }

    private func filterEntriesRecursively(_ entries: [ZipEntry], query: String) -> [ZipEntry] {
        var filtered: [ZipEntry] = []

        for entry in entries {
            let matchesQuery = entry.name.lowercased().contains(query)
            let filteredChildren = filterEntriesRecursively(entry.children, query: query)

            if matchesQuery || !filteredChildren.isEmpty {
                var newEntry = entry
                newEntry.children = filteredChildren
                filtered.append(newEntry)
            }
        }

        return filtered
    }

    func openZipFile(at url: URL) {
        // Stop accessing previous security-scoped resource if any
        #if os(iOS)
        if let previousURL = securityScopedURL {
            previousURL.stopAccessingSecurityScopedResource()
        }
        // Start accessing security-scoped resource for iOS
        // This is required to read files from document picker
        if url.startAccessingSecurityScopedResource() {
            securityScopedURL = url
        }
        #endif

        isLoading = true
        errorMessage = nil
        showError = false
        currentZipURL = url
        loadingProgress = 0
        loadedEntryCount = 0

        Task {
            do {
                let loadedEntries = try await archiveManager.openArchive(at: url) { progress, count in
                    Task { @MainActor in
                        self.loadingProgress = progress
                        self.loadedEntryCount = count
                    }
                }
                await MainActor.run {
                    self.entries = loadedEntries
                    self.selectedEntries.removeAll()
                    self.isLoading = false
                    self.loadingProgress = 0
                    self.loadedEntryCount = 0
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                    self.loadingProgress = 0
                    self.loadedEntryCount = 0
                }
            }
        }
    }

    deinit {
        // Clean up security-scoped resource access
        #if os(iOS)
        if let url = securityScopedURL {
            url.stopAccessingSecurityScopedResource()
        }
        #endif
    }

    func extractSelected(to destinationURL: URL) {
        guard !selectedEntries.isEmpty else { return }

        // Start accessing security-scoped resource for destination on iOS
        #if os(iOS)
        let accessing = destinationURL.startAccessingSecurityScopedResource()
        #endif

        isExtracting = true
        extractionProgress = 0

        Task {
            do {
                let entriesToExtract = Array(selectedEntries)
                try archiveManager.extractEntries(entriesToExtract, to: destinationURL) { progress, fileName in
                    Task { @MainActor in
                        self.extractionProgress = progress
                        self.extractionFileName = fileName
                    }
                }

                await MainActor.run {
                    self.isExtracting = false
                    self.extractionProgress = 0
                    self.extractionFileName = ""
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isExtracting = false
                    self.extractionProgress = 0
                }
            }

            // Stop accessing security-scoped resource on iOS
            #if os(iOS)
            if accessing {
                destinationURL.stopAccessingSecurityScopedResource()
            }
            #endif
        }
    }

    func extractEntry(_ entry: ZipEntry, to destinationURL: URL) async {
        // Start accessing security-scoped resource for destination on iOS
        #if os(iOS)
        let accessing = destinationURL.startAccessingSecurityScopedResource()
        #endif

        await MainActor.run {
            isExtracting = true
            extractionProgress = 0
            extractionFileName = entry.name
        }

        do {
            try archiveManager.extractEntry(entry, to: destinationURL) { progress in
                Task { @MainActor in
                    self.extractionProgress = progress
                }
            }

            await MainActor.run {
                self.isExtracting = false
                self.extractionProgress = 0
                self.extractionFileName = ""
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isExtracting = false
                self.extractionProgress = 0
            }
        }

        // Stop accessing security-scoped resource on iOS
        #if os(iOS)
        if accessing {
            destinationURL.stopAccessingSecurityScopedResource()
        }
        #endif
    }

    func extractAll(to destinationURL: URL) {
        // Start accessing security-scoped resource for destination on iOS
        #if os(iOS)
        let accessing = destinationURL.startAccessingSecurityScopedResource()
        #endif

        isExtracting = true
        extractionProgress = 0

        Task {
            do {
                try archiveManager.extractAll(to: destinationURL) { progress, fileName in
                    Task { @MainActor in
                        self.extractionProgress = progress
                        self.extractionFileName = fileName
                    }
                }

                await MainActor.run {
                    self.isExtracting = false
                    self.extractionProgress = 0
                    self.extractionFileName = ""
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isExtracting = false
                    self.extractionProgress = 0
                }
            }

            // Stop accessing security-scoped resource on iOS
            #if os(iOS)
            if accessing {
                destinationURL.stopAccessingSecurityScopedResource()
            }
            #endif
        }
    }

    func getPreviewData(for entry: ZipEntry) async throws -> Data {
        return try archiveManager.getPreviewData(for: entry)
    }

    func toggleSelection(_ entry: ZipEntry) {
        if selectedEntries.contains(entry) {
            selectedEntries.remove(entry)
        } else {
            selectedEntries.insert(entry)
        }
    }

    func selectMultiple(_ entries: [ZipEntry]) {
        for entry in entries {
            selectedEntries.insert(entry)
        }
    }

    func clearSelection() {
        selectedEntries.removeAll()
        lastSelectedEntry = nil
    }

    func selectAll(from entries: [ZipEntry]) {
        selectedEntries = Set(entries)
        lastSelectedEntry = entries.last
    }

    func selectRange(from: ZipEntry, to: ZipEntry, in entries: [ZipEntry]) {
        guard let fromIndex = entries.firstIndex(of: from),
              let toIndex = entries.firstIndex(of: to) else {
            return
        }

        let startIndex = min(fromIndex, toIndex)
        let endIndex = max(fromIndex, toIndex)

        for i in startIndex...endIndex {
            selectedEntries.insert(entries[i])
        }
    }

    func selectSingle(_ entry: ZipEntry) {
        selectedEntries = [entry]
        lastSelectedEntry = entry
        focusedEntry = entry
    }

    func selectSingleForNavigation(_ entry: ZipEntry) {
        selectedEntries = [entry]
        focusedEntry = entry
        // Don't update lastSelectedEntry - preserve anchor for shift+arrow
    }

    func copySelectedPaths() {
        let paths = selectedEntries.map { $0.path }.joined(separator: "\n")
        PlatformPasteboard.copy(paths)
    }
}
