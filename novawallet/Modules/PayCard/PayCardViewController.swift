import UIKit
import WebKit
import SnapKit

private struct WebViewScript {
    enum InsertionPoint {
        case atDocStart
        case atDocEnd
    }

    let content: String
    let insertionPoint: InsertionPoint
}

private enum CallbackNames: String {
    case onStatusChange
    case onSellTransferEnabled
    case onRequestIntercept
}

final class PayCardViewController: UIViewController, ViewHolder {
    typealias RootViewType = PayCardViewLayout

    let userContentController = WKUserContentController()

    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()

        configuration.userContentController = userContentController

        let preferences = WKWebpagePreferences()
        preferences.preferredContentMode = .mobile
        configuration.defaultWebpagePreferences = preferences

        let view = WKWebView(frame: .zero, configuration: configuration)

        view.scrollView.contentInsetAdjustmentBehavior = .always
        view.scrollView.backgroundColor = R.color.colorSecondaryScreenBackground()

        if #available(iOS 16.4, *) {
            view.isInspectable = true
        }

        return view
    }()

    let presenter: PayCardPresenterProtocol

    init(presenter: PayCardPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = PayCardViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()

        setupWebView()
        startWebView()
    }

    func setupWebView() {
        rootView.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        webView.navigationDelegate = self
        webView.uiDelegate = self

        addWidgetScript()
        addRequestInterceptingScript()
    }

    func startWebView() {
        guard
            let htmlFile = Bundle.main.path(forResource: "mercuryoWidget", ofType: "html"),
            let htmlString = try? String(contentsOfFile: htmlFile, encoding: .utf8)
        else {
            return
        }

        webView.loadHTMLString(
            htmlString,
            baseURL: URL(string: "https://exchange.mercuryo.io")!
        )
    }

    private func addRequestInterceptingScript() {
        userContentController.add(self, name: CallbackNames.onRequestIntercept.rawValue)

        let specificUrl = "https://api.mercuryo.io/v1.6/cards"

        let scriptSource = """
        (function() {
                let originalXhrOpen = XMLHttpRequest.prototype.open;
                let originalXhrSend = XMLHttpRequest.prototype.send;
                let originalSetRequestHeader = XMLHttpRequest.prototype.setRequestHeader;

                XMLHttpRequest.prototype.open = function(method, url) {
                    this.interceptedUrl = url;
                    this.interceptedMethod = method;
                    this.interceptedHeaders = {};
                    originalXhrOpen.apply(this, arguments);
                };

                XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
                    this.interceptedHeaders[header] = value;
                    originalSetRequestHeader.apply(this, arguments);
                };

                XMLHttpRequest.prototype.send = function(body) {
                    if (this.interceptedUrl && this.interceptedUrl.includes('\(specificUrl)')) {
                        let cookieHeader = document.cookie; // Capture cookies manually

                        window.webkit.messageHandlers.onRequestIntercept.postMessage({
                            url: this.interceptedUrl,
                            method: this.interceptedMethod,
                            headers: this.interceptedHeaders,
                            cookies: cookieHeader,
                            body: body,
                            referer: document.referrer,
                            origin: window.location.origin,
                            userAgent: navigator.userAgent
                        });
                    }
                    originalXhrSend.apply(this, arguments);
                };
            })();
        """

        let wkScript = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )

        userContentController.addUserScript(wkScript)
    }

    private func addWidgetScript() {
        userContentController.add(self, name: CallbackNames.onSellTransferEnabled.rawValue)
        userContentController.add(self, name: CallbackNames.onStatusChange.rawValue)

        let script = WebViewScript(
            content: """
            mercuryoWidget.run({
                widgetId: '4ce98182-ed76-4933-ba1b-b85e4a51d75a',
                host: document.getElementById('widget-container'),
                type: 'sell',
                currency: 'DOT',
                fiatCurrency: 'EUR',
                paymentMethod: 'fiat_card_open',
                theme: 'nova',
                showSpendCardDetails: true,
                width: '100%',
                fixPaymentMethod: true,
                height: window.innerHeight,
                hideRefundAddress: true,
                refundAddress: '14iKGFDp5EBXe3sdX765ngrERMrYUdxmFfayNCGkq7f6tm9w',
                onStatusChange: data => {
                    window.webkit.messageHandlers.onStatusChange.postMessage(JSON.stringify(data))
                },
                onSellTransferEnabled: data => {
                    window.webkit.messageHandlers.onSellTransferEnabled.postMessage(JSON.stringify(data))
                }
            });
            """,
            insertionPoint: .atDocEnd
        )

        let wkScript = WKUserScript(
            source: script.content,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )

        userContentController.addUserScript(wkScript)
    }

    private func handleJavaScriptInterceptedRequest(data: [String: Any]) {
        guard let urlString = data["url"] as? String,
              let url = URL(string: urlString),
              let method = data["method"] as? String,
              let headers = data["headers"] as? [String: String] else {
            print("Invalid data received from JavaScript")
            return
        }

        // Get cookies from WKWebView's cookie store
        getCookiesForUrl(url: url) { cookies in
            // Create a URLRequest
            var request = URLRequest(url: url)
            request.httpMethod = method

            // Set headers
            for (headerField, headerValue) in headers {
                request.setValue(headerValue, forHTTPHeaderField: headerField)
            }

            // Add cookies to the request
            if let origin = data["origin"] as? String {
                request.setValue(origin, forHTTPHeaderField: "Origin")
                request.setValue(origin, forHTTPHeaderField: "Referer")
            }
            if let userAgent = data["userAgent"] as? String {
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            }

            // Set the body if present and if the method allows it
            if let body = data["body"] as? String, !body.isEmpty,
               let httpBody = body.data(using: .utf8), method != "GET" {
                request.httpBody = httpBody
            }

            Logger.shared.debug("Header: \(request.allHTTPHeaderFields)")

            // Perform the request using URLSession
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    Logger.shared.error("Error occurred during URLSession request: \(error)")
                    return
                }

                if let response = response as? HTTPURLResponse {
                    Logger.shared.debug("Response status code: \(response.statusCode)")
                }

                if let data = data {
                    if let responseString = String(data: data, encoding: .utf8) {
                        Logger.shared.debug("Response data: \(responseString)")
                    }
                }
            }
            task.resume()
        }
    }

    private func getCookiesForUrl(url: URL, completion: @escaping ([HTTPCookie]) -> Void) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        var cookies: [HTTPCookie] = []

        cookieStore.getAllCookies { allCookies in
            for cookie in allCookies {
                let domainMatches = url.host?.contains(cookie.domain) == true

                if domainMatches {
                    cookies.append(cookie)
                }
            }
            completion(cookies)
        }
    }
}

extension PayCardViewController: WKScriptMessageHandler {
    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            let data = "\(message.body)".data(using: .utf8),
            let callbackName = CallbackNames(rawValue: message.name)
        else {
            return
        }

        switch callbackName {
        case .onStatusChange:
            presenter.processWidgetState(data: data)
        case .onSellTransferEnabled:
            presenter.processTransferData(data: data)
        case .onRequestIntercept:
            Logger.shared.debug("Intercepted: \(message.body)")

            if let body = message.body as? [String: Any] {
                handleJavaScriptInterceptedRequest(data: body)
            }
        }
    }
}

extension PayCardViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }

        return nil
    }
}

extension PayCardViewController: PayCardViewProtocol {
    func didReceiveRefundAddress(_: String) {}
}
