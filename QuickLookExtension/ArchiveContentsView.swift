import SwiftUI

/// SwiftUI view shown inside the Quick Look preview panel: a header summarising
/// the archive plus an expandable outline of its contents.
struct ArchiveContentsView: View {
    let nodes: [ArchiveNode]
    let summary: ArchiveSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 320, minHeight: 200)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.zipper")
                .foregroundStyle(.secondary)
            Text(summaryText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if nodes.isEmpty {
            VStack {
                Spacer()
                Text("Empty archive")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List(nodes, children: \.children) { node in
                row(for: node)
            }
            .listStyle(.inset)
        }
    }

    private func row(for node: ArchiveNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: node.isDirectory ? "folder.fill" : icon(for: node.name))
                .foregroundStyle(node.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: 18)
            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            Text(ByteCountFormatter.string(fromByteCount: Int64(node.size), countStyle: .file))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryText: String {
        let files = "\(summary.fileCount) file\(summary.fileCount == 1 ? "" : "s")"
        let folders = "\(summary.folderCount) folder\(summary.folderCount == 1 ? "" : "s")"
        let size = ByteCountFormatter.string(fromByteCount: Int64(summary.totalSize), countStyle: .file)
        return "\(files) · \(folders) · \(size)"
    }

    private func icon(for name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "heic", "bmp", "tiff", "webp":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "txt", "md", "rtf":
            return "doc.text"
        case "zip", "gz", "tar", "7z", "rar", "bz2", "xz":
            return "doc.zipper"
        case "mp3", "wav", "aac", "m4a", "flac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv", "m4v":
            return "film"
        case "swift", "py", "js", "ts", "java", "c", "cpp", "h", "rb", "go", "rs", "kt":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "xml", "yaml", "yml", "toml":
            return "doc.badge.gearshape"
        default:
            return "doc"
        }
    }
}
