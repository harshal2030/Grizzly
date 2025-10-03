import Foundation
import ZIPFoundation

class ZipArchiveManager {
    private var archive: Archive?
    private var archiveURL: URL?

    enum ZipError: LocalizedError {
        case invalidArchive
        case fileNotFound
        case extractionFailed(String)
        case readFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidArchive:
                return "Invalid or corrupted zip archive"
            case .fileNotFound:
                return "File not found in archive"
            case .extractionFailed(let message):
                return "Extraction failed: \(message)"
            case .readFailed(let message):
                return "Read failed: \(message)"
            }
        }
    }

    func openArchive(at url: URL, progress: ((Double, Int) -> Void)? = nil) async throws -> [ZipEntry] {
        let archive = try Archive(url: url, accessMode: .read)

        self.archive = archive
        self.archiveURL = url

        return try await buildEntryTree(from: archive, progress: progress)
    }

    private func buildEntryTree(from archive: Archive, progress: ((Double, Int) -> Void)? = nil) async throws -> [ZipEntry] {
        var flatEntries: [ZipEntry] = []
        var directoryMap: [String: ZipEntry] = [:]

        // Count total entries first (fast iteration)
        let totalCount = archive.reduce(0) { count, _ in count + 1 }
        var processedCount = 0
        let chunkSize = 1000 // Process in chunks of 1000 entries

        // First pass: create all entries with chunked processing
        for entry in archive {
            let path = entry.path
            let name = (path as NSString).lastPathComponent
            let isDirectory = entry.type == .directory

            let zipEntry = ZipEntry(
                path: path,
                name: name.isEmpty ? path : name,
                isDirectory: isDirectory,
                uncompressedSize: UInt64(entry.uncompressedSize),
                compressedSize: UInt64(entry.compressedSize),
                modificationDate: entry.fileAttributes[.modificationDate] as? Date,
                parentPath: (path as NSString).deletingLastPathComponent
            )

            flatEntries.append(zipEntry)

            if isDirectory {
                directoryMap[path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))] = zipEntry
            }

            processedCount += 1

            // Yield control back to allow UI updates every chunk
            if processedCount % chunkSize == 0 {
                let progressValue = Double(processedCount) / Double(totalCount)
                progress?(progressValue * 0.8, processedCount) // 80% for entry loading
                await Task.yield()
            }
        }

        progress?(0.8, totalCount) // Entry loading complete

        // Build hierarchical structure
        let hierarchy = buildHierarchy(from: flatEntries)
        progress?(1.0, totalCount) // Complete

        return hierarchy
    }

    private func buildHierarchy(from entries: [ZipEntry]) -> [ZipEntry] {
        var rootEntries: [ZipEntry] = []
        var entryMap: [String: ZipEntry] = [:]

        // Create a map of all entries
        for entry in entries {
            entryMap[entry.path] = entry
        }

        // Build the hierarchy
        for entry in entries {
            let parentPath = (entry.path as NSString).deletingLastPathComponent

            if parentPath.isEmpty || parentPath == "." {
                // Root level entry
                rootEntries.append(entry)
            } else {
                // Find parent and add as child
                if var parent = entryMap[parentPath] ?? entryMap[parentPath + "/"] {
                    parent.children.append(entry)
                    entryMap[parent.path] = parent
                } else {
                    // Parent not found, treat as root
                    rootEntries.append(entry)
                }
            }
        }

        // Update entryMap with children
        for (key, value) in entryMap {
            if var updatedEntry = entryMap[key] {
                updatedEntry.children = value.children.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                entryMap[key] = updatedEntry
            }
        }

        // Recursively update children
        rootEntries = rootEntries.map { updateChildrenRecursively(entry: $0, entryMap: entryMap) }

        return rootEntries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func updateChildrenRecursively(entry: ZipEntry, entryMap: [String: ZipEntry]) -> ZipEntry {
        var updatedEntry = entry

        if let mappedEntry = entryMap[entry.path] {
            updatedEntry.children = mappedEntry.children.map { updateChildrenRecursively(entry: $0, entryMap: entryMap) }
        }

        return updatedEntry
    }

    func extractEntry(_ entry: ZipEntry, to destinationURL: URL, progress: ((Double) -> Void)? = nil) throws {
        guard let archive = archive else {
            throw ZipError.invalidArchive
        }

        guard let archiveEntry = archive[entry.path] else {
            throw ZipError.fileNotFound
        }

        let finalDestination: URL
        if entry.isDirectory {
            finalDestination = destinationURL.appendingPathComponent(entry.name, isDirectory: true)
        } else {
            finalDestination = destinationURL.appendingPathComponent(entry.name)
        }

        do {
            let extractProgress = Progress(totalUnitCount: Int64(entry.uncompressedSize))
            _ = try archive.extract(archiveEntry, to: finalDestination, skipCRC32: false, progress: extractProgress)

            // Call progress callback if provided
            progress?(1.0)
        } catch {
            throw ZipError.extractionFailed(error.localizedDescription)
        }
    }

    func extractEntries(_ entries: [ZipEntry], to destinationURL: URL, progress: ((Double, String) -> Void)? = nil) throws {
        let totalEntries = Double(entries.count)

        for (index, entry) in entries.enumerated() {
            progress?(Double(index) / totalEntries, entry.name)
            try extractEntry(entry, to: destinationURL)
        }

        progress?(1.0, "Complete")
    }

    func extractAll(to destinationURL: URL, progress: ((Double, String) -> Void)? = nil) throws {
        guard let archiveURL = archiveURL else {
            throw ZipError.invalidArchive
        }

        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        do {
            let extractProgress = Progress(totalUnitCount: 100)
            extractProgress.cancellationHandler = {
                // Handle cancellation if needed
            }

            try FileManager.default.unzipItem(at: archiveURL, to: destinationURL, progress: extractProgress)

            // Monitor progress if callback is provided
            if let progressCallback = progress {
                progressCallback(1.0, "Extracting...")
            }
        } catch {
            throw ZipError.extractionFailed(error.localizedDescription)
        }
    }

    func getPreviewData(for entry: ZipEntry) throws -> Data {
        guard let archive = archive else {
            throw ZipError.invalidArchive
        }

        guard let archiveEntry = archive[entry.path] else {
            throw ZipError.fileNotFound
        }

        var data = Data()
        do {
            _ = try archive.extract(archiveEntry, skipCRC32: true) { chunk in
                data.append(chunk)
            }
        } catch {
            throw ZipError.readFailed(error.localizedDescription)
        }

        return data
    }

    func closeArchive() {
        archive = nil
        archiveURL = nil
    }
}
