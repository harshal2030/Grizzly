import Foundation
import ZIPFoundation

class ZipArchiveManager {
    private var archive: Archive?
    private var archiveURL: URL?
    private(set) var isPasswordProtected: Bool = false

    enum ZipError: LocalizedError {
        case invalidArchive
        case fileNotFound
        case extractionFailed(String)
        case readFailed(String)
        case passwordProtected

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
            case .passwordProtected:
                return "This archive is password protected and cannot be opened. WIP for password support."
            }
        }
    }

    // MARK: - ZIP Metadata Detection

    /// Detects if a ZIP archive is password protected by reading the Central Directory
    private func detectPasswordProtection(at url: URL) throws -> Bool {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        // Get file size
        let fileSize = try fileHandle.seekToEnd()
        guard fileSize > 22 else { return false } // Minimum ZIP file size

        // Search for End of Central Directory Record in last 65KB
        // (ZIP comment can be max 65535 bytes, plus 22 bytes for EOCD)
        let searchStart = max(0, fileSize - 65536)
        try fileHandle.seek(toOffset: UInt64(searchStart))
        let data = fileHandle.readDataToEndOfFile()

        // Find End of Central Directory signature: 0x06054b50 (little-endian)
        let eocdSignature: UInt32 = 0x06054b50
        guard let eocdOffset = findSignature(eocdSignature, in: data) else {
            return false
        }

        // EOCD structure (after signature):
        // 0-1: disk number
        // 2-3: disk where central directory starts
        // 4-5: number of central directory records on this disk
        // 6-7: total number of central directory records
        // 8-11: size of central directory
        // 12-15: offset of start of central directory

        let eocdData = data.advanced(by: eocdOffset)
        guard eocdData.count >= 22 else { return false }

        let totalEntries = eocdData.readUInt16(at: 10) // offset 10 from signature
        let cdSize = eocdData.readUInt32(at: 12) // offset 12 from signature
        let cdOffset = eocdData.readUInt32(at: 16) // offset 16 from signature

        // Read Central Directory headers to check encryption flags
        try fileHandle.seek(toOffset: UInt64(cdOffset))
        let cdData = fileHandle.readData(ofLength: Int(cdSize))

        return hasEncryptedEntries(in: cdData, count: Int(totalEntries))
    }

    /// Find a signature (4 bytes) in data, searching from end to beginning
    private func findSignature(_ signature: UInt32, in data: Data) -> Int? {
        let signatureBytes = withUnsafeBytes(of: signature.littleEndian) { Data($0) }

        // Search backwards for better performance (EOCD is typically at the end)
        for i in stride(from: data.count - 4, through: 0, by: -1) {
            if data[i..<i+4] == signatureBytes {
                return i
            }
        }
        return nil
    }

    /// Check if any entries in the Central Directory have the encryption bit set
    private func hasEncryptedEntries(in cdData: Data, count: Int) -> Bool {
        var offset = 0
        let cdSignature: UInt32 = 0x02014b50 // Central Directory header signature

        for _ in 0..<count {
            guard offset + 46 <= cdData.count else { break }

            // Verify Central Directory signature
            let signature = cdData.readUInt32(at: offset)
            guard signature == cdSignature else { break }

            // Read general purpose bit flag (offset 8 from signature)
            let bitFlag = cdData.readUInt16(at: offset + 8)

            // Bit 0: if set, file is encrypted
            if (bitFlag & 0x0001) != 0 {
                return true
            }

            // Move to next Central Directory header
            // 46 = fixed size of Central Directory header
            let fileNameLength = cdData.readUInt16(at: offset + 28)
            let extraFieldLength = cdData.readUInt16(at: offset + 30)
            let commentLength = cdData.readUInt16(at: offset + 32)

            offset += 46 + Int(fileNameLength) + Int(extraFieldLength) + Int(commentLength)
        }

        return false
    }

    func openArchive(at url: URL, progress: ((Double, Int) -> Void)? = nil) async throws -> [ZipEntry] {
        // Check for password protection before opening
        isPasswordProtected = try detectPasswordProtection(at: url)

        if isPasswordProtected {
            throw ZipError.passwordProtected
        }

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
        for entry: Entry in archive {
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

// MARK: - Data Reading Extensions

extension Data {
    /// Read a UInt16 at the specified offset (little-endian)
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt16.self)
        }
    }

    /// Read a UInt32 at the specified offset (little-endian)
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self)
        }
    }
}
