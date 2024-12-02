import Foundation
import WebKit

protocol WebViewPoolProtocol {
    func getWebView(for id: UUID) -> WKWebView?
    func setupWebView(for id: UUID) -> WKWebView
}
