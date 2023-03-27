import Foundation

struct DAppBrowserPage {
    let url: URL
    let title: String

    var identifier: String { url.absoluteString }

    var domain: String {
        url.host ?? url.absoluteString
    }
}
