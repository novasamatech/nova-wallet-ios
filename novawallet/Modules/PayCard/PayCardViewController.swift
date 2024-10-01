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
}

extension PayCardViewController {
    var userContentController: WKUserContentController {
        let userController = WKUserContentController()
        userController.add(self, name: CallbackNames.onSellTransferEnabled.rawValue)
        userController.add(self, name: CallbackNames.onStatusChange.rawValue)

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
                    window.webkit.messageHandlers.onSellTransferEnabled.postMessage(JSON.stringify(data))
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
        userController.addUserScript(wkScript)

        return userController
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
