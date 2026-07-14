import XCTest
import ZIPFoundation
@testable import Grizzly

/// Exercises the extraction path end-to-end against real archives, focusing on
/// the two behaviours the recent rewrite of `ZipArchiveManager` addresses:
/// folder contents actually extract, and malicious `../` entries cannot escape
/// the chosen destination (Zip-Slip).
final class ExtractionSafetyTests: XCTestCase {

    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GrizzlyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    // MARK: - Helpers

    private func addFile(_ archive: Archive, path: String, contents: String) throws {
        let data = Data(contents.utf8)
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
            let start = Int(position)
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }

    private func addDirectory(_ archive: Archive, path: String) throws {
        try archive.addEntry(with: path, type: .directory, uncompressedSize: Int64(0)) { (_: Int64, _: Int) in Data() }
    }

    /// Recursively finds the first entry in the loaded tree matching `path`.
    private func find(_ path: String, in entries: [ZipEntry]) -> ZipEntry? {
        for entry in entries {
            if entry.path == path || entry.path == path + "/" { return entry }
            if let hit = find(path, in: entry.children) { return hit }
        }
        return nil
    }

    // MARK: - Tests

    /// Selecting a folder extracts the folder *and* all of its nested contents,
    /// preserving the directory structure on disk.
    func testExtractingFolderWritesAllDescendants() async throws {
        let zipURL = tmpDir.appendingPathComponent("normal.zip")
        let archive = try Archive(url: zipURL, accessMode: .create)
        try addDirectory(archive, path: "top/")
        try addDirectory(archive, path: "top/sub/")
        try addFile(archive, path: "top/a.txt", contents: "AAA")
        try addFile(archive, path: "top/sub/b.txt", contents: "BBB")

        let manager = ZipArchiveManager()
        let entries = try await manager.openArchive(at: zipURL)

        let top = try XCTUnwrap(find("top", in: entries), "expected a nested 'top' folder in the tree")
        XCTAssertTrue(top.isDirectory)

        let dest = tmpDir.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

        // Extract the folder only — its children must come along for the ride.
        try await manager.extractEntries([top], to: dest)

        let a = dest.appendingPathComponent("top/a.txt")
        let b = dest.appendingPathComponent("top/sub/b.txt")
        XCTAssertEqual(try String(contentsOf: a, encoding: .utf8), "AAA")
        XCTAssertEqual(try String(contentsOf: b, encoding: .utf8), "BBB")
    }

    /// A crafted entry whose path escapes the destination via `../` must be
    /// rejected and must not write anything outside the destination folder.
    func testZipSlipEntryIsRejected() async throws {
        let zipURL = tmpDir.appendingPathComponent("evil.zip")
        let archive = try Archive(url: zipURL, accessMode: .create)
        try addFile(archive, path: "../escape.txt", contents: "PWNED")

        let manager = ZipArchiveManager()
        let entries = try await manager.openArchive(at: zipURL)
        let evil = try XCTUnwrap(find("../escape.txt", in: entries), "expected the malicious entry to load")

        let dest = tmpDir.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)

        do {
            try await manager.extractEntries([evil], to: dest)
            XCTFail("expected extraction of a path-traversal entry to throw")
        } catch ZipArchiveManager.ZipError.extractionFailed {
            // expected — the containment guard rejected the entry
        } catch {
            XCTFail("expected .extractionFailed, got \(error)")
        }

        // The escape target (a sibling of `dest`) must never have been created.
        let escaped = tmpDir.appendingPathComponent("escape.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: escaped.path),
                       "Zip-Slip write escaped the destination directory")
    }
}
