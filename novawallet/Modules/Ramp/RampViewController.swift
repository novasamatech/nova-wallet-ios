import UIKit
import WebKit

final class RampViewController: UIViewController, ViewHolder {
    typealias RootViewType = PayCardViewLayout

    private var scriptsHandler: DAppBrowserScriptHandler?

    var presenter: RampPresenterProtocol!

    private var isSetupPresenter: Bool = false

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

extension RampViewController: DAppBrowserScriptHandlerDelegate {
    func browserScriptHandler(_: DAppBrowserScriptHandler, didReceive message: WKScriptMessage) {
        presenter.processMessage(body: message.body, of: message.name)
    }
}

// MARK: WKNavigationDelegate

extension RampViewController: WKNavigationDelegate, WKUIDelegate {
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

    func webView(
        _: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @MainActor(URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        }
    }
}

// MARK: RampViewProtocol

extension RampViewController: RampViewProtocol {
    func didReceive(model: RampModel) {
        let transport = DAppTransportModel(
            name: "Ramp",
            handlerNames: model.messageNames,
            scripts: model.scripts
        )

        scriptsHandler?.bind(viewModel: transport)

        load(resource: model.resource)
    }
}
