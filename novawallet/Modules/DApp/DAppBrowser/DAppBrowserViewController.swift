import UIKit
import WebKit

final class DAppBrowserViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppBrowserViewLayout

    let presenter: DAppBrowserPresenterProtocol

    private var viewModel: DAppBrowserModel?

    private var urlObservation: NSKeyValueObservation?
    private var goBackObservation: NSKeyValueObservation?
    private var goForwardObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?

    private var scriptMessageHandlers: [String: DAppBrowserScriptHandler] = [:]

    init(presenter: DAppBrowserPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        urlObservation?.invalidate()
        goBackObservation?.invalidate()
        goForwardObservation?.invalidate()
        titleObservation?.invalidate()
    }

    override func loadView() {
        view = DAppBrowserViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        presenter.setup()
    }

    private func configure() {
        navigationItem.titleView = rootView.urlBar

        navigationItem.leftItemsSupplementBackButton = false
        navigationItem.leftBarButtonItem = rootView.closeBarItem

        rootView.closeBarItem.target = self
        rootView.closeBarItem.action = #selector(actionClose)

        rootView.webView.uiDelegate = self
        rootView.webView.allowsBackForwardNavigationGestures = true

        urlObservation = rootView.webView.observe(\.url, options: [.initial, .new]) { [weak self] _, change in
            guard let newValue = change.newValue, let url = newValue else {
                return
            }

            self?.didChangeUrl(url)
        }

        goBackObservation = rootView.webView.observe(
            \.canGoBack,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let newValue = change.newValue else {
                return
            }

            self?.didChangeGoBack(newValue)
        }

        goForwardObservation = rootView.webView.observe(
            \.canGoForward,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let newValue = change.newValue else {
                return
            }

            self?.didChangeGoForward(newValue)
        }

        titleObservation = rootView.webView.observe(
            \.title,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let newValue = change.newValue, let title = newValue else {
                return
            }

            self?.didChangeTitle(title)
        }

        rootView.goBackBarItem.target = self
        rootView.goBackBarItem.action = #selector(actionGoBack)

        rootView.goForwardBarItem.target = self
        rootView.goForwardBarItem.action = #selector(actionGoForward)

        rootView.refreshBarItem.target = self
        rootView.refreshBarItem.action = #selector(actionRefresh)

        rootView.favoriteBarButton.isEnabled = false
        rootView.favoriteBarButton.target = self
        rootView.favoriteBarButton.action = #selector(actionFavorite)

        rootView.urlBar.addTarget(self, action: #selector(actionSearch), for: .touchUpInside)
    }

    private func didChangeTitle(_ title: String) {
        guard let url = rootView.webView.url else {
            return
        }

        let page = DAppBrowserPage(url: url, title: title)
        presenter.process(page: page)
    }

    private func didChangeUrl(_ newUrl: URL) {
        rootView.urlLabel.text = newUrl.host

        if newUrl.isTLSScheme {
            rootView.securityImageView.image = R.image.iconBrowserSecurity()
        } else {
            rootView.securityImageView.image = nil
        }

        rootView.urlBar.setNeedsLayout()

        let title = rootView.webView.title ?? ""

        let page = DAppBrowserPage(url: newUrl, title: title)
        presenter.process(page: page)
    }

    private func setupTransports(_ transports: [DAppTransportModel]) {
        let contentController = rootView.webView.configuration.userContentController
        contentController.removeAllUserScripts()

        scriptMessageHandlers = transports.reduce(
            into: scriptMessageHandlers
        ) { handlers, transport in
            let handler = handlers[transport.name] ?? DAppBrowserScriptHandler(
                contentController: contentController,
                delegate: self
            )

            handler.bind(viewModel: transport)

            handlers[transport.name] = handler
        }
    }

    private func setupUrl(_ url: URL) {
        rootView.urlLabel.text = url.host

        if url.isTLSScheme {
            rootView.securityImageView.image = R.image.iconBrowserSecurity()
        } else {
            rootView.securityImageView.image = nil
        }

        rootView.urlBar.setNeedsLayout()

        let request = URLRequest(url: url)
        rootView.webView.load(request)

        rootView.goBackBarItem.isEnabled = rootView.webView.canGoBack
        rootView.goForwardBarItem.isEnabled = rootView.webView.canGoForward
    }

    private func didChangeGoBack(_ newValue: Bool) {
        rootView.goBackBarItem.isEnabled = newValue
    }

    private func didChangeGoForward(_: Bool) {
        rootView.goForwardBarItem.isEnabled = rootView.webView.canGoForward
    }

    @objc private func actionGoBack() {
        rootView.webView.goBack()
    }

    @objc private func actionGoForward() {
        rootView.webView.goForward()
    }

    @objc private func actionRefresh() {
        rootView.webView.reload()
    }

    @objc private func actionFavorite() {
        presenter.toggleFavorite()
    }

    @objc private func actionSearch() {
        presenter.activateSearch(with: rootView.webView.url?.absoluteString)
    }

    @objc private func actionClose() {
        presenter.close()
    }
}

extension DAppBrowserViewController: DAppBrowserScriptHandlerDelegate {
    func browserScriptHandler(_: DAppBrowserScriptHandler, didReceive message: WKScriptMessage) {
        let host = rootView.webView.url?.host ?? ""

        presenter.process(message: message.body, host: host, transport: message.name)
    }
}

extension DAppBrowserViewController: DAppBrowserViewProtocol {
    func didReceive(viewModel: DAppBrowserModel) {
        setupTransports(viewModel.transports)
        setupUrl(viewModel.url)
    }

    func didReceive(response: DAppScriptResponse, forTransport _: String) {
        rootView.webView.evaluateJavaScript(response.content)
    }

    func didReceiveReplacement(
        transports: [DAppTransportModel],
        postExecution script: DAppScriptResponse
    ) {
        setupTransports(transports)

        rootView.webView.evaluateJavaScript(script.content)
    }

    func didReceiveFavorite(flag: Bool) {
        rootView.favoriteBarButton.isEnabled = true

        let icon = flag ? R.image.iconFavToolbarSel() : R.image.iconFavToolbar()
        rootView.favoriteBarButton.image = icon?.withRenderingMode(.alwaysOriginal)
    }
}

extension DAppBrowserViewController: WKUIDelegate {
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
