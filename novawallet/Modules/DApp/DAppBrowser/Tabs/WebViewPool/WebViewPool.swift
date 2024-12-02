import Foundation
import WebKit

class WebViewPool {
    private var webViewDict: [UUID: WKWebView] = [:]
}

// MARK: WebViewPoolProtocol

extension WebViewPool: WebViewPoolProtocol {
    func getWebView(for id: UUID) -> WKWebView? {
        webViewDict[id]
    }

    func setupWebView(for id: UUID) -> WKWebView {
        if let existingWebView = webViewDict[id] {
            return existingWebView
        }

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.scrollView.contentInsetAdjustmentBehavior = .always
        view.scrollView.backgroundColor = R.color.colorSecondaryScreenBackground()

        webViewDict[id] = view

        return view
    }
}

// MARK: Singleton

extension WebViewPool {
    static let shared = WebViewPool()
}
