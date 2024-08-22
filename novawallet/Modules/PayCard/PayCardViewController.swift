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

final class PayCardViewController: UIViewController, ViewHolder {
    typealias RootViewType = PayCardViewLayout

    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()

        configuration.userContentController = userContentController

        let preferences = WKWebpagePreferences()
        preferences.preferredContentMode = .mobile
        configuration.defaultWebpagePreferences = preferences

        let view = WKWebView(frame: .zero, configuration: configuration)

        view.scrollView.contentInsetAdjustmentBehavior = .always
        view.scrollView.backgroundColor = R.color.colorSecondaryScreenBackground()

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
        webView.loadHTMLString(
            page,
            baseURL: URL(string: "https://exchange.mercuryo.io")!
        )
    }

    func setupWebView() {
        rootView.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        webView.navigationDelegate = self
        webView.uiDelegate = self

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        } else {
            // Fallback on earlier versions
        }
    }
}

extension PayCardViewController {
    var page: String {
        """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Mercuryo Widget</title>
            </head>
            <body>
                <div id="widget-container"></div>

                <script src="https://widget.mercuryo.io/embed.2.0.js"></script>
            </body>
            </html>
        """
    }

    var userContentController: WKUserContentController {
        let userController = WKUserContentController()

        let script = WebViewScript(
            content: """
            mercuryoWidget.run({
                widgetId: '4ce98182-ed76-4933-ba1b-b85e4a51d75a',
                host: document.getElementById('widget-container'),
                type: 'sell',
                currency: 'DOT',
                fiatCurrency: 'EUR',
                paymentMethod: 'fiat_card_open',
                width: '100%',
                fixPaymentMethod: true,
                height: window.innerHeight,
                hideRefundAddress: true,
                refundAddress: '16PkUq6HiR1Zc4KZ2fbWNmdbxYymynEnrxRhzpjWYVxuNodT',
                onStatusChange: data => {

                },
                onSellTransferEnabled: data => {

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
        userController.addUserScript(wkScript)

        return userController
    }
}

extension PayCardViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(_: WKWebView, didFinish _: WKNavigation!) {}

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

    func webView(_: WKWebView, didFail _: WKNavigation!, withError _: any Error) {
        print("did_fail")
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

    func webView(
        _: WKWebView,
        runJavaScriptAlertPanelWithMessage _: String,
        initiatedByFrame _: WKFrameInfo,
        completionHandler _: @escaping () -> Void
    ) {
        print("runJavaScriptAlertPanelWithMessage")
    }

    func webView(_: WKWebView, shouldAllowDeprecatedTLSFor _: URLAuthenticationChallenge) async -> Bool {
        print("deprecated_tls")

        return true
    }

    func webView(_: WKWebView, didReceiveServerRedirectForProvisionalNavigation _: WKNavigation!) {
        print("")
    }

    func webViewWebContentProcessDidTerminate(_: WKWebView) {
        print("terminate")
    }
}

extension PayCardViewController: PayCardViewProtocol {}
