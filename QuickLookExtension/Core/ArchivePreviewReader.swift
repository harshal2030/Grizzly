import Foundation
import ZIPFoundation

/// A node in the previewed archive's file tree.
struct ArchiveNode: Identifiable {
    /// Full path within the archive — stable and unique, so it doubles as the id.
    let id: String
    let name: String
    let isDirectory: Bool
    /// Uncompressed size in bytes; for directories this is the aggregate of all
    /// descendants.
    let size: UInt64
    /// `nil` marks a leaf (file); a (possibly empty) array marks a directory.
    var children: [ArchiveNode]?
}

/// High-level counts shown in the preview header.
struct ArchiveSummary {
    let fileCount: Int
    let folderCount: Int
    let totalSize: UInt64
}

enum ArchivePreviewError: Error {
    case unreadable
}

/// Reads a ZIP archive's central directory (metadata only, never the file
/// contents) and builds a hierarchical tree for the Quick Look preview. Missing
/// intermediate directories are synthesized so archives that omit explicit
/// folder entries still render with structure.
enum ArchivePreviewReader {

    /// Mutable tree node used only while walking the archive's flat entry list.
    private final class BuildNode {
        let name: String
        var isDirectory: Bool
        var size: UInt64 = 0
        var children: [String: BuildNode] = [:]

        init(name: String, isDirectory: Bool) {
            self.name = name
            self.isDirectory = isDirectory
        }
    }

    static func read(url: URL) throws -> (nodes: [ArchiveNode], summary: ArchiveSummary) {
        guard let archive = try? Archive(url: url, accessMode: .read) else {
            throw ArchivePreviewError.unreadable
        }

        let root = BuildNode(name: "", isDirectory: true)
        var fileCount = 0
        var totalSize: UInt64 = 0

        for entry in archive {
            let components = entry.path
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
            guard !components.isEmpty else { continue }

            let entryIsDirectory = entry.type == .directory
            let entrySize = UInt64(max(entry.uncompressedSize, 0))

            // Walk/create the path, treating every non-final component as a folder.
            var node = root
            for (index, component) in components.enumerated() {
                let isLast = index == components.count - 1
                let childIsDirectory = isLast ? entryIsDirectory : true

                if let existing = node.children[component] {
                    node = existing
                } else {
                    let created = BuildNode(name: component, isDirectory: childIsDirectory)
                    node.children[component] = created
                    node = created
                }
            }

            if !entryIsDirectory {
                node.isDirectory = false
                node.size = entrySize
                fileCount += 1
                totalSize += entrySize
            }
        }

        var folderCount = 0

        func convert(_ node: BuildNode, path: String) -> ArchiveNode {
            if node.children.isEmpty && !node.isDirectory {
                return ArchiveNode(id: path, name: node.name, isDirectory: false, size: node.size, children: nil)
            }

            folderCount += 1
            let kids = node.children.values
                .map { convert($0, path: path + "/" + $0.name) }
                .sorted(by: Self.order)
            let aggregate = kids.reduce(UInt64(0)) { $0 + $1.size }
            return ArchiveNode(id: path, name: node.name, isDirectory: true, size: aggregate, children: kids)
        }

        let topLevel = root.children.values
            .map { convert($0, path: $0.name) }
            .sorted(by: Self.order)

        let summary = ArchiveSummary(fileCount: fileCount, folderCount: folderCount, totalSize: totalSize)
        return (topLevel, summary)
    }

    /// Sort folders before files, then case-insensitive by name.
    private static func order(_ lhs: ArchiveNode, _ rhs: ArchiveNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
