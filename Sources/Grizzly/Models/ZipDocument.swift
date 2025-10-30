import SwiftUI
import UniformTypeIdentifiers

struct ZipDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }

    init(configuration: ReadConfiguration) throws {
        // We don't need to store anything - the file URL is available via @Environment
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // We're not writing zip files, only reading them
        throw CocoaError(.featureUnsupported)
    }
}
