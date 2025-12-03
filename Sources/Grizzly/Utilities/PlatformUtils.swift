import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Platform-specific color extensions
extension Color {
    static var platformControlBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}

// MARK: - Platform-specific file operations
struct PlatformFileManager {
    static func openFile(at url: URL) -> Bool {
        #if os(macOS)
        return NSWorkspace.shared.open(url)
        #else
        // On iOS, we'll use the share sheet instead
        return false
        #endif
    }

    static func revealFileInSystem(at url: URL) {
        #if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #else
        // On iOS, this operation doesn't make sense
        // We could potentially show a share sheet or file manager
        #endif
    }
}

// MARK: - Platform-specific Pasteboard
struct PlatformPasteboard {
    static func copy(_ string: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }
}

// MARK: - File Picker for SwiftUI
struct FilePicker: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var selectedURL: URL?
    let allowedTypes: [UTType]
    let allowsMultiple: Bool
    let canChooseDirectories: Bool
    let canChooseFiles: Bool
    let onSelection: (URL?) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                #if os(macOS)
                FilePickerMacOS(
                    selectedURL: $selectedURL,
                    allowedTypes: allowedTypes,
                    allowsMultiple: allowsMultiple,
                    canChooseDirectories: canChooseDirectories,
                    canChooseFiles: canChooseFiles,
                    onSelection: onSelection
                )
                #else
                FilePickerIOS(
                    selectedURL: $selectedURL,
                    allowedTypes: allowedTypes,
                    canChooseDirectories: canChooseDirectories,
                    onSelection: onSelection
                )
                #endif
            }
    }
}

extension View {
    func filePicker(
        isPresented: Binding<Bool>,
        selectedURL: Binding<URL?>,
        allowedTypes: [UTType] = [.folder],
        allowsMultiple: Bool = false,
        canChooseDirectories: Bool = true,
        canChooseFiles: Bool = false,
        onSelection: @escaping (URL?) -> Void
    ) -> some View {
        self.modifier(FilePicker(
            isPresented: isPresented,
            selectedURL: selectedURL,
            allowedTypes: allowedTypes,
            allowsMultiple: allowsMultiple,
            canChooseDirectories: canChooseDirectories,
            canChooseFiles: canChooseFiles,
            onSelection: onSelection
        ))
    }
}

// MARK: - macOS File Picker
#if os(macOS)
struct FilePickerMacOS: View {
    @Binding var selectedURL: URL?
    let allowedTypes: [UTType]
    let allowsMultiple: Bool
    let canChooseDirectories: Bool
    let canChooseFiles: Bool
    let onSelection: (URL?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text(canChooseDirectories ? "Select Destination Folder" : "Select File")
                .font(.headline)

            Button("Choose...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = canChooseFiles
                panel.canChooseDirectories = canChooseDirectories
                panel.allowsMultipleSelection = allowsMultiple
                panel.canCreateDirectories = true
                panel.allowedContentTypes = allowedTypes

                if panel.runModal() == .OK {
                    selectedURL = panel.url
                    // Immediately trigger the selection callback and dismiss
                    onSelection(selectedURL)
                    dismiss()
                }
            }
            .buttonStyle(.bordered)

            if let destination = selectedURL {
                Text(destination.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(canChooseDirectories ? "Select" : "Open") {
                    onSelection(selectedURL)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedURL == nil)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
#endif

// MARK: - iOS File Picker
#if os(iOS)
import UniformTypeIdentifiers

struct FilePickerIOS: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    let allowedTypes: [UTType]
    let canChooseDirectories: Bool
    let onSelection: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        if canChooseDirectories {
            picker.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePickerIOS

        init(_ parent: FilePickerIOS) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.selectedURL = url
            parent.onSelection(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onSelection(nil)
        }
    }
}
#endif

// MARK: - Share functionality for iOS
#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
