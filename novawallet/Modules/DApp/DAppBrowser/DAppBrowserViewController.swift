import UIKit
import WebKit
import Foundation_iOS
import UIKit_iOS

final class DAppBrowserViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppBrowserViewLayout

    let presenter: DAppBrowserPresenterProtocol

    let logger: LoggerProtocol

    private let webViewPool: WebViewPoolProtocol

    private var viewModel: DAppBrowserModel?

    private var urlObservation: NSKeyValueObservation?
    private var goBackObservation: NSKeyValueObservation?
    private var goForwardObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var isDesktop: Bool = false
    private var transports: [DAppTransportModel] = []
    private var scriptMessageHandlers: [String: DAppBrowserScriptHandler] = [:]

    private let localizationManager: LocalizationManagerProtocol
    private let localRouter: URLLocalRouting
    private let deviceOrientationManager: DeviceOrientationManaging

    private var scrollYOffset: CGFloat = 0
    private var barsHideOffset: CGFloat = 20
    private lazy var slidingAnimator = BlockViewAnimator(duration: 0.2, delay: 0, options: [.curveLinear])
    private var isBarHidden: Bool = false

    private var selectedLocale: Locale {
        localizationManager.selectedLocale
    }

    var isLandscape: Bool {
        traitCollection.verticalSizeClass == .compact
    }

    init(
        presenter: DAppBrowserPresenterProtocol,
        localRouter: URLLocalRouting,
        webViewPool: WebViewPoolProtocol,
        deviceOrientationManager: DeviceOrientationManaging,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.presenter = presenter
        self.logger = logger
        self.localRouter = localRouter
        self.webViewPool = webViewPool
        self.deviceOrientationManager = deviceOrientationManager
        self.localizationManager = localizationManager

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        deviceOrientationManager.enableLandscape()
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let isOldLandscape = traitCollection.verticalSizeClass == .compact

        super.viewWillTransition(to: size, with: coordinator)

        let isNewLandscape = size.width > size.height

        if !isOldLandscape, isNewLandscape {
            hideBars()
        } else if isOldLandscape, !isNewLandscape {
            showBars()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        presenter.setup()
    }

    func canBeDismissedInteractively() -> Bool {
        !isLandscape
    }

    func willBeDismissedInteractively() {
        snapshotWebView { [weak self] image in
            let render = DAppBrowserTabRender(for: image)
            self?.presenter.willDismissInteractive(stateRender: render)
        }
    }
}

// MARK: Private

private extension DAppBrowserViewController {
    func configure() {
        navigationItem.titleView = rootView.urlBar

        navigationItem.leftItemsSupplementBackButton = false
        navigationItem.leftBarButtonItem = rootView.minimizeBarItem
        navigationItem.rightBarButtonItem = rootView.refreshBarItem

        rootView.minimizeBarItem.target = self
        rootView.minimizeBarItem.action = #selector(actionClose)

        configureWebView()
        configureHandlers()
    }

    func configureWebView() {
        rootView.webView?.uiDelegate = self
        rootView.webView?.navigationDelegate = self
        rootView.webView?.scrollView.delegate = self
        rootView.webView?.allowsBackForwardNavigationGestures = true

        configureObservers()
    }

    func configureObservers() {
        urlObservation = rootView.webView?.observe(\.url, options: [.initial, .new]) { [weak self] _, change in
            // allow to change url here only for the same origin to prevent spoofing
            // https://github.com/mozilla-mobile/firefox-ios/wiki/WKWebView-navigation-and-security-considerations
            guard
                let oldValue = change.oldValue,
                let newValue = change.newValue,
                let oldUrl = oldValue,
                let newUrl = newValue,
                URL.hasSameOrigin(oldUrl, newUrl) else {
                // didCommit delegate should catch origin change
                return
            }

            self?.didChangeUrl(newUrl)
        }

        goBackObservation = rootView.webView?.observe(
            \.canGoBack,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let newValue = change.newValue else {
                return
            }

            self?.didChangeGoBack(newValue)
        }

        goForwardObservation = rootView.webView?.observe(
            \.canGoForward,
            options: [.initial, .new]
        ) { [weak self] _, change in
            guard let newValue = change.newValue else {
                return
            }

            self?.didChangeGoForward(newValue)
        }
    }

    func makeStateRender() {
        snapshotWebView { [weak self] image in
            let render = DAppBrowserTabRender(for: image)
            self?.presenter.process(stateRender: render)
        }
    }

    func configureHandlers() {
        rootView.goBackBarItem.target = self
        rootView.goBackBarItem.action = #selector(actionGoBack)

        rootView.goForwardBarItem.target = self
        rootView.goForwardBarItem.action = #selector(actionGoForward)

        rootView.tabsButton.addTarget(
            self,
            action: #selector(actionTabs),
            for: .touchUpInside
        )

        rootView.favoriteBarItem.target = self
        rootView.favoriteBarItem.action = #selector(actionFavorite)

        rootView.refreshBarItem.target = self
        rootView.refreshBarItem.action = #selector(actionRefresh)

        rootView.settingsBarButton.target = self
        rootView.settingsBarButton.action = #selector(actionSettings)

        rootView.urlBar.addTarget(self, action: #selector(actionSearch), for: .touchUpInside)
    }

    func didChangeUrl(_ newUrl: URL) {
        rootView.urlLabel.text = newUrl.host

        rootView.setURLSecure(newUrl.isTLSScheme)

        rootView.urlBar.setNeedsLayout()

        let title = rootView.webView?.title ?? ""

        let page = DAppBrowserPage(url: newUrl, title: title)
        presenter.process(page: page)
    }

    func setupUrl(
        _ url: URL?,
        with reload: Bool
    ) {
        guard let url else { return }

        rootView.urlLabel.text = url.host

        rootView.setURLSecure(url.isTLSScheme)

        rootView.urlBar.setNeedsLayout()

        if reload {
            let request = URLRequest(url: url)
            rootView.webView?.load(request)
        }

        rootView.goBackBarItem.isEnabled = rootView.webView?.canGoBack ?? false
        rootView.goForwardBarItem.isEnabled = rootView.webView?.canGoForward ?? false
    }

    func setupScripts() {
        guard let contentController = rootView.webView?.configuration.userContentController else {
            return
        }

        contentController.removeAllUserScripts()

        setupTransports(
            transports,
            for: contentController
        )
        setupAdditionalUserScripts(for: contentController)
    }

    func setupTransports(
        _ transports: [DAppTransportModel],
        for contentController: WKUserContentController
    ) {
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

    func setupAdditionalUserScripts(for contentController: WKUserContentController) {
        guard let webView = rootView.webView else { return }

        if isDesktop {
            let script = WKUserScript(
                source: webView.viewportScript(targetWidthInPixels: WKWebView.desktopWidth),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )

            contentController.addUserScript(script)
        }
    }

    func setupWebPreferences() {
        let preferences = WKWebpagePreferences()
        preferences.preferredContentMode = isDesktop ? .desktop : .mobile
        rootView.webView?.configuration.defaultWebpagePreferences = preferences

        if isDesktop {
            rootView.webView?.customUserAgent = WKWebView.deskstopUserAgent
        } else {
            rootView.webView?.customUserAgent = nil
        }
    }

    func showBars() {
        guard isBarHidden else {
            return
        }

        isBarHidden = false

        navigationController?.setNavigationBarHidden(false, animated: true)

        slidingAnimator.animate(block: { [weak self] in
            self?.rootView.setIsToolbarHidden(false)
        }, completionBlock: nil)
    }

    func hideBars() {
        guard !isBarHidden else {
            return
        }

        isBarHidden = true

        navigationController?.setNavigationBarHidden(true, animated: true)

        slidingAnimator.animate(block: { [weak self] in
            self?.rootView.setIsToolbarHidden(true)
        }, completionBlock: nil)
    }

    func didChangeGoBack(_ newValue: Bool) {
        rootView.goBackBarItem.isEnabled = newValue
    }

    func didChangeGoForward(_: Bool) {
        rootView.goForwardBarItem.isEnabled = rootView.webView?.canGoForward ?? false
    }

    func snapshotWebView(completion: @escaping (UIImage?) -> Void) {
        guard let webView = rootView.webView else {
            completion(nil)
            return
        }

        let snapshotConfiguration = WKSnapshotConfiguration()
        snapshotConfiguration.rect = webView.bounds
        snapshotConfiguration.afterScreenUpdates = false

        webView.takeSnapshot(with: snapshotConfiguration) { [weak self] image, error in
            guard let image = image else {
                self?.logger.error("Failed to take snapshot: \(String(describing: error))")

                completion(nil)
                return
            }

            completion(image)
        }
    }

    func setupWebView(with viewModel: DAppBrowserModel) {
        let newTabView: WKWebView

        scriptMessageHandlers = [:]

        if let existingTab = webViewPool.getWebView(for: viewModel.selectedTab.uuid) {
            newTabView = existingTab
        } else {
            newTabView = webViewPool.setupWebView(for: viewModel.selectedTab.uuid)
        }

        rootView.webView?.configuration.userContentController.removeAllUserScripts()

        makeStateRender()
        rootView.setWebView(newTabView)
        configureWebView()
    }

    @objc private func actionGoBack() {
        rootView.webView?.goBack()
    }

    @objc private func actionGoForward() {
        rootView.webView?.goForward()
    }

    @objc private func actionFavorite() {
        presenter.actionFavorite()
    }

    @objc private func actionRefresh() {
        rootView.webView?.reload()
    }

    @objc private func actionSettings() {
        presenter.showSettings(using: isDesktop)
    }

    @objc private func actionSearch() {
        presenter.activateSearch()
    }

    @objc private func actionClose() {
        snapshotWebView { [weak self] image in
            let stateRender = DAppBrowserTabRender(for: image)
            self?.presenter.close(stateRender: stateRender)
        }
    }

    @objc private func actionTabs() {
        snapshotWebView { [weak self] image in
            let stateRender = DAppBrowserTabRender(for: image)
            self?.presenter.showTabs(stateRender: stateRender)
        }
    }
}

// MARK: DAppBrowserScriptHandlerDelegate

extension DAppBrowserViewController: DAppBrowserScriptHandlerDelegate {
    func browserScriptHandler(_: DAppBrowserScriptHandler, didReceive message: WKScriptMessage) {
        presenter.process(message: message.body, transport: message.name)
    }
}

// MARK: DAppBrowserViewProtocol

extension DAppBrowserViewController: DAppBrowserViewProtocol {
    func didReceiveRenderRequest() {
        makeStateRender()
    }

    func idForTransitioningTab() -> UUID? {
        viewModel?.selectedTab.uuid
    }

    func didReceive(viewModel: DAppBrowserModel) {
        var reload: Bool = true

        if self.viewModel?.selectedTab.uuid != viewModel.selectedTab.uuid {
            reload = !webViewPool.webViewExists(for: viewModel.selectedTab.uuid)
            setupWebView(with: viewModel)
        }

        if !reload {
            let page = DAppBrowserPage(
                url: viewModel.selectedTab.url,
                title: rootView.webView?.title ?? ""
            )

            presenter.process(page: page)
        }

        self.viewModel = viewModel

        isDesktop = viewModel.isDesktop
        transports = viewModel.transports

        setupScripts()
        setupWebPreferences()

        setupUrl(
            viewModel.selectedTab.url,
            with: reload
        )
    }

    func didReceiveTabsCount(viewModel: DAppBrowserTabsButtonViewModel) {
        switch viewModel {
        case let .count(text):
            rootView.tabsButton.imageWithTitleView?.iconImage = nil
            rootView.tabsButton.imageWithTitleView?.title = text
        case .icon:
            rootView.tabsButton.imageWithTitleView?.iconImage = R.image.iconSiriPawBrowser()
            rootView.tabsButton.imageWithTitleView?.title = nil
        }
    }

    func didReceive(response: DAppScriptResponse) {
        rootView.webView?.evaluateJavaScript(response.content)
    }

    func didReceiveReplacement(
        transports: [DAppTransportModel],
        postExecution script: DAppScriptResponse
    ) {
        self.transports = transports
        setupScripts()

        rootView.webView?.evaluateJavaScript(script.content)
    }

    func didSet(isDesktop: Bool) {
        guard self.isDesktop != isDesktop else {
            return
        }

        self.isDesktop = isDesktop

        setupScripts()
        setupWebPreferences()
        rootView.webView?.reload()
    }

    func didSet(canShowSettings: Bool) {
        rootView.settingsBarButton.isEnabled = canShowSettings
    }

    func didSet(favorite: Bool) {
        rootView.setFavorite(favorite)
    }

    func didDecideClose() {
        deviceOrientationManager.disableLandscape()
        setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

// MARK: UIScrollViewDelegate

extension DAppBrowserViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard isLandscape else {
            return
        }

        scrollYOffset = scrollView.contentOffset.y
    }

    func scrollViewDidScrollToTop(_: UIScrollView) {
        showBars()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging, isLandscape else {
            return
        }

        let scrollDiff = scrollView.contentOffset.y - scrollYOffset
        let isScrollingUp = scrollDiff > 0 && scrollView.contentOffset.y > 0 && abs(scrollDiff) >= barsHideOffset
        let isScrollingDown = scrollDiff < 0 && abs(scrollDiff) >= barsHideOffset

        if isScrollingUp {
            hideBars()
        } else if isScrollingDown {
            showBars()
        }

        scrollYOffset = scrollView.contentOffset.y
    }
}

// MARK: WKUIDelegate, WKNavigationDelegate

extension DAppBrowserViewController: WKUIDelegate, WKNavigationDelegate {
    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if
            let url = navigationAction.request.url,
            localRouter.canOpenLocalUrl(url) {
            localRouter.openLocalUrl(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didCommit _: WKNavigation) {
        guard let url = webView.url else {
            return
        }

        didChangeUrl(url)
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        presenter.didLoadPage()
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
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame _: WKFrameInfo,
        completionHandler: @escaping @MainActor(Bool) -> Void
    ) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        let languages = selectedLocale.rLanguages
        let confirmTitle = R.string.localizable.commonConfirmTitle(
            preferredLanguages: languages
        )

        alertController.addAction(UIAlertAction(title: confirmTitle, style: .default, handler: { _ in
            completionHandler(true)
        }))

        let cancelTitle = R.string.localizable.commonCancel(
            preferredLanguages: languages
        )

        alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: { _ in
            completionHandler(false)
        }))

        present(alertController, animated: true, completion: nil)
    }

    func webView(
        _: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame _: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        let languages = selectedLocale.rLanguages
        let okTitle = R.string.localizable.commonOk(
            preferredLanguages: languages
        )

        alertController.addAction(UIAlertAction(title: okTitle, style: .default, handler: { _ in
            completionHandler()
        }))

        present(alertController, animated: true, completion: nil)
    }
}
