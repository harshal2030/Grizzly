import Foundation
import UniformTypeIdentifiers

struct ZipEntry: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let isDirectory: Bool
    let uncompressedSize: UInt64
    let compressedSize: UInt64
    let modificationDate: Date?
    var children: [ZipEntry]
    let parentPath: String?
    var childrenLoaded: Bool
    var childCount: Int

    init(path: String, name: String, isDirectory: Bool, uncompressedSize: UInt64, compressedSize: UInt64, modificationDate: Date?, children: [ZipEntry] = [], parentPath: String? = nil, childrenLoaded: Bool = true, childCount: Int = 0) {
        self.path = path
        self.name = name
        self.isDirectory = isDirectory
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.modificationDate = modificationDate
        self.children = children
        self.parentPath = parentPath
        self.childrenLoaded = childrenLoaded
        self.childCount = childCount
    }

    var icon: String {
        if isDirectory {
            return "folder.fill"
        }

        let ext = (name as NSString).pathExtension.lowercased()

        switch ext {
        case "txt", "md", "text":
            return "doc.text.fill"
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv":
            return "film.fill"
        case "mp3", "wav", "aac", "m4a":
            return "music.note"
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        case "swift", "py", "js", "java", "cpp", "c", "h":
            return "chevron.left.forwardslash.chevron.right"
        case "html", "css":
            return "globe"
        case "json", "xml", "yaml", "yml":
            return "doc.badge.gearshape"
        default:
            return "doc.fill"
        }
    }

    var totalUncompressedSize: UInt64 {
        if isDirectory {
            return children.reduce(0) { $0 + $1.totalUncompressedSize }
        }
        return uncompressedSize
    }

    var totalCompressedSize: UInt64 {
        if isDirectory {
            return children.reduce(0) { $0 + $1.totalCompressedSize }
        }
        return compressedSize
    }

    var formattedSize: String {
        let size = isDirectory ? totalUncompressedSize : uncompressedSize
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var formattedCompressedSize: String {
        let size = isDirectory ? totalCompressedSize : compressedSize
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var compressionRatio: Double {
        let uncompressed = isDirectory ? totalUncompressedSize : uncompressedSize
        guard uncompressed > 0 else { return 0 }
        let compressed = isDirectory ? totalCompressedSize : compressedSize
        return Double(compressed) / Double(uncompressed)
    }

    var fileType: String {
        if isDirectory {
            return "Folder"
        }

        let ext = (name as NSString).pathExtension
        if ext.isEmpty {
            return "File"
        }

        if let type = UTType(filenameExtension: ext) {
            return type.localizedDescription ?? ext.uppercased()
        }

        return ext.uppercased()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ZipEntry, rhs: ZipEntry) -> Bool {
        lhs.id == rhs.id
    }
}
