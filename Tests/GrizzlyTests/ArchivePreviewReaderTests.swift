import XCTest
import ZIPFoundation
@testable import GrizzlyArchiveKit

/// Verifies the Quick Look preview builds a correct contents tree from a real
/// archive — including synthesizing intermediate folders that aren't stored as
/// explicit entries, which is common in real-world zips.
final class ArchivePreviewReaderTests: XCTestCase {

    private var tmpDir: URL!

    override func setUpWithError() throws {
        tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("GrizzlyQLTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    private func addFile(_ archive: Archive, path: String, bytes: Int) throws {
        let data = Data(repeating: 0x41, count: bytes)
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(bytes)) { (position: Int64, size: Int) in
            let start = Int(position)
            let end = min(start + size, data.count)
            return data.subdata(in: start..<end)
        }
    }

    private func child(_ name: String, of node: ArchiveNode) -> ArchiveNode? {
        node.children?.first { $0.name == name }
    }

    /// An archive with only file entries (no explicit folder entries) must still
    /// produce the full folder hierarchy, with folders sorted before files.
    func testBuildsTreeAndSynthesizesMissingDirectories() throws {
        let zipURL = tmpDir.appendingPathComponent("nested.zip")
        let archive = try Archive(url: zipURL, accessMode: .create)
        try addFile(archive, path: "docs/readme.md", bytes: 10)
        try addFile(archive, path: "docs/img/logo.png", bytes: 100)
        try addFile(archive, path: "top.txt", bytes: 5)

        let (nodes, _) = try ArchivePreviewReader.read(url: zipURL)

        // Top level: folder "docs" (synthesized — never an explicit entry)
        // sorted before file "top.txt".
        XCTAssertEqual(nodes.map(\.name), ["docs", "top.txt"])
        XCTAssertTrue(nodes[0].isDirectory)
        XCTAssertFalse(nodes[1].isDirectory)
        XCTAssertNotNil(nodes[0].children)
    }

    /// Full structural + summary assertions.
    func testTreeStructureCountsAndAggregateSize() throws {
        let zipURL = tmpDir.appendingPathComponent("structure.zip")
        let archive = try Archive(url: zipURL, accessMode: .create)
        try addFile(archive, path: "docs/readme.md", bytes: 10)
        try addFile(archive, path: "docs/img/logo.png", bytes: 100)
        try addFile(archive, path: "top.txt", bytes: 5)

        let (nodes, summary) = try ArchivePreviewReader.read(url: zipURL)

        let docs = try XCTUnwrap(nodes.first { $0.name == "docs" })
        XCTAssertTrue(docs.isDirectory)
        XCTAssertNotNil(docs.children)

        // docs contains synthesized folder "img" (sorted first) and "readme.md".
        XCTAssertEqual(docs.children?.map(\.name), ["img", "readme.md"])
        let img = try XCTUnwrap(child("img", of: docs))
        XCTAssertTrue(img.isDirectory)
        XCTAssertEqual(img.children?.map(\.name), ["logo.png"])

        // Directory sizes aggregate their descendants.
        XCTAssertEqual(img.size, 100)
        XCTAssertEqual(docs.size, 110)   // 10 + 100

        // Files are leaves (children == nil); folders are not.
        let top = try XCTUnwrap(nodes.first { $0.name == "top.txt" })
        XCTAssertNil(top.children)
        XCTAssertEqual(top.size, 5)

        // Summary: 3 files, 2 folders (docs, img), 115 bytes total.
        XCTAssertEqual(summary.fileCount, 3)
        XCTAssertEqual(summary.folderCount, 2)
        XCTAssertEqual(summary.totalSize, 115)
    }
}
