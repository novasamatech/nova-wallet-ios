import Foundation
import WebKit

final class WebViewPool {
    private var webViewDict: [UUID: WKWebView] = [:]

    private let workingQueue = DispatchQueue(
        label: Constants.readWriteQueueLabel,
        qos: .userInitiated,
        attributes: [.concurrent]
    )

    private var syncWebViewDict: [UUID: WKWebView] {
        get {
            workingQueue.sync { webViewDict }
        }
        set {
            workingQueue.async(flags: .barrier) {
                self.webViewDict = newValue
            }
        }
    }
}

// MARK: WebViewPoolProtocol

extension WebViewPool: WebViewPoolProtocol {
    func getWebView(for id: UUID) -> WKWebView? {
        syncWebViewDict[id]
    }

    func setupWebView(for id: UUID) -> WKWebView {
        if let existingWebView = syncWebViewDict[id] {
            return existingWebView
        }

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = WKUserContentController()

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.scrollView.contentInsetAdjustmentBehavior = .always
        view.scrollView.backgroundColor = R.color.colorSecondaryScreenBackground()

        syncWebViewDict[id] = view

        return view
    }

    func removeWebView(for id: UUID) {
        syncWebViewDict[id] = nil
    }

    func removeAll() {
        syncWebViewDict = [:]
    }

    func webViewExists(for id: UUID) -> Bool {
        syncWebViewDict[id] != nil
    }
}

// MARK: Constants

private extension WebViewPool {
    enum Constants {
        static let readWriteQueueLabel: String = "WebViewPool.readWriteQueue"
    }
}

// MARK: Singleton

extension WebViewPool {
    static let shared = WebViewPool()
}
