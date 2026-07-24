import Cocoa
import Quartz
import SwiftUI

/// Principal class of the Quick Look preview extension. macOS instantiates it
/// when a `.zip` is previewed (Finder spacebar, Mail, etc.), hands us the file
/// URL, and displays our view in the preview panel.
class PreviewViewController: NSViewController, QLPreviewingController {

    override func loadView() {
        // No nib/storyboard — build a plain container we fill with a hosting view.
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let result = try ArchivePreviewReader.read(url: url)
            let hosting = NSHostingView(
                rootView: ArchiveContentsView(nodes: result.nodes, summary: result.summary)
            )
            hosting.translatesAutoresizingMaskIntoConstraints = false

            view.subviews.forEach { $0.removeFromSuperview() }
            view.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hosting.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            handler(nil)
        } catch {
            handler(error)
        }
    }
}
