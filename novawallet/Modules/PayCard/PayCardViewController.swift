import UIKit
import WebKit

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

    private var scriptsHandler: DAppBrowserScriptHandler?

    let presenter: PayCardPresenterProtocol

    private var isSetupPresenter: Bool = false

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

        setupWebView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !isSetupPresenter {
            isSetupPresenter = true

            presenter.setup()
        }
    }

    func setupWebView() {
        scriptsHandler = DAppBrowserScriptHandler(
            contentController: rootView.webView.configuration.userContentController,
            delegate: self
        )

        rootView.webView.navigationDelegate = self
        rootView.webView.uiDelegate = self
    }

    func load(resource: PayCardResource) {
        let request = URLRequest(url: resource.url)

        rootView.webView.load(request)
    }
}

// MARK: DAppBrowserScriptHandlerDelegate

extension PayCardViewController: DAppBrowserScriptHandlerDelegate {
    func browserScriptHandler(_: DAppBrowserScriptHandler, didReceive message: WKScriptMessage) {
        presenter.processMessage(body: message.body, of: message.name)
    }
}

// MARK: WKNavigationDelegate

extension PayCardViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.targetFrame == nil {
            rootView.webView.load(navigationAction.request)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(
        _: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            rootView.webView.load(navigationAction.request)
        }

        return nil
    }
}

// MARK: PayCardViewProtocol

extension PayCardViewController: PayCardViewProtocol {
    func didReceive(model: PayCardModel) {
        let transport = DAppTransportModel(
            name: "PayCard",
            handlerNames: model.messageNames,
            scripts: model.scripts
        )

        scriptsHandler?.bind(viewModel: transport)

        load(resource: model.resource)
    }
}
