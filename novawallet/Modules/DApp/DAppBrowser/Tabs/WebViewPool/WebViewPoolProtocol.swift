import Foundation
import WebKit

@MainActor
protocol WebViewPoolEraserProtocol {
    func removeWebView(for id: UUID)
    func removeAll()
}

@MainActor
protocol WebViewPoolProtocol: WebViewPoolEraserProtocol {
    func getWebView(for id: UUID) -> WKWebView?
    func webViewExists(for id: UUID) -> Bool
    func setupWebView(for id: UUID) -> WKWebView
}
