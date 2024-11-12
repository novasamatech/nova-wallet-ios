import Foundation
import WebKit

struct DAppBrowserModel {
    let url: URL
    let isDesktop: Bool
    let transports: [DAppTransportModel]
}

struct DAppBrowserTabModel {
    let uuid: UUID
    let url: URL
    let title: String?
    let isDesktop: Bool
    let transports: [DAppTransportModel]
    let state: Data?
}

struct DAppBrowserTabViewModel {
    let tab: DAppBrowserTabModel
    let loadRequired: Bool
    let webView: WKWebView
}
