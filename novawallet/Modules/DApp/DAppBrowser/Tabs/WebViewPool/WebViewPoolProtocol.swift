import Foundation
import WebKit

protocol WebViewPoolEraserProtocol {
    func removeWebView(for id: UUID)
    func removeAll()
}

protocol WebViewPoolProtocol: WebViewPoolEraserProtocol {
    func getWebView(for id: UUID) -> WKWebView?
    func webViewExists(for id: UUID) -> Bool
    func setupWebView(for id: UUID) -> WKWebView
}
