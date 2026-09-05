import SafariServices
import SwiftUI

struct InAppBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true
        return SFSafariViewController(url: url, configuration: configuration)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct InAppBrowserDestination: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
