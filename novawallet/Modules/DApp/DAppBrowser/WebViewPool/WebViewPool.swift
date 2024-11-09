import Foundation
import WebKit

protocol WebViewPoolProtocol {
    func getWebView(for uuid: UUID) -> WKWebView?
    func setupWebView(for uuid: UUID) -> WKWebView
}

class WebViewPool {
    private var webViewDict: [UUID: WKWebView] = [:]
}

extension WebViewPool: WebViewPoolProtocol {
    func getWebView(for uuid: UUID) -> WKWebView? {
        webViewDict[uuid]
    }
    
    func setupWebView(for uuid: UUID) -> WKWebView {
        if let existingWebView = webViewDict[uuid] {
            return existingWebView
        }
        
        let webView = WKWebView()
        
        webViewDict[uuid] = webView
        
        return webView
    }
}
