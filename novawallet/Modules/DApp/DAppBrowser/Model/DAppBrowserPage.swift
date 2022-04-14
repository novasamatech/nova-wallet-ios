import Foundation

struct DAppBrowserPage {
    let url: URL
    let title: String

    var identifier: String { url.absoluteString }
}
