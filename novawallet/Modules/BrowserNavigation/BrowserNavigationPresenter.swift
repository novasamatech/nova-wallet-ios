import Foundation
import Operation_iOS

final class BrowserNavigationPresenter {
    let interactor: BrowserNavigationInteractorInputProtocol
    let browserNavigationTaskFactory: BrowserNavigationTaskFactoryProtocol

    weak var mainAppContainer: NovaMainAppContainerViewProtocol?

    private var wallet: MetaAccountModel?
    private var dAppsResult: Result<DAppList, Error>?
    private var categoryModels: [DAppCategory] = []
    private var favorites: [String: DAppFavorite]?

    private var browserNavigationTask: BrowserNavigationTask?
    private var pendingTab: DAppBrowserTab?

    init(
        interactor: BrowserNavigationInteractorInputProtocol,
        browserNavigationTaskFactory: BrowserNavigationTaskFactoryProtocol
    ) {
        self.interactor = interactor
        self.browserNavigationTaskFactory = browserNavigationTaskFactory
    }

    // MARK: Pre-browser routing

    /// Routes a built tab: if the URL is a known third-party staking domain, present the
    /// warning sheet and stash the tab for replay on Continue; otherwise open the browser
    /// directly. Drops re-entrant requests while a warning is already on screen, matching
    /// the phishing-flow modal-blocking semantics.
    private func routeOrWarn(tab: DAppBrowserTab) {
        guard pendingTab == nil else { return }

        if ThirdPartyStakingDomainMatcher.isBlocked(url: tab.url) {
            pendingTab = tab
            presentStakingWarning(
                for: tab.url,
                from: mainAppContainer?.controller.topModalViewController,
                delegate: self
            )
        } else {
            mainAppContainer?.openBrowser(with: tab)
        }
    }

    /// Test seam: exposes `routeOrWarn(tab:)` for unit tests without forcing them through
    /// the full `BrowserNavigationTask` pipeline. Production callers always go through
    /// the task's `routingClosure`, which calls into `routeOrWarn(tab:)` (see openBrowser
    /// methods below).
    func routeOrWarnForTesting(tab: DAppBrowserTab) {
        routeOrWarn(tab: tab)
    }
}

// MARK: BrowserNavigationProtocol

extension BrowserNavigationPresenter: BrowserNavigationProtocol {
    func openBrowser(with dAppId: String) {
        browserNavigationTask = browserNavigationTaskFactory.createDAppNavigationTaskById(
            dAppId,
            wallet: wallet,
            favoritesProvider: { [weak self] in self?.favorites },
            dAppResultProvider: { [weak self] in self?.dAppsResult }
        )
        browserNavigationTask?(cleaner: self)
    }

    func openBrowser(with model: DAppNavigation) {
        browserNavigationTask = browserNavigationTaskFactory.createDAppNavigationTaskByModel(
            model,
            wallet: wallet,
            dAppResultProvider: { [weak self] in self?.dAppsResult }
        )
        browserNavigationTask?(cleaner: self)
    }

    func openBrowser(with result: DAppSearchResult) {
        guard let wallet else { return }

        browserNavigationTask = browserNavigationTaskFactory.createSearchResultNavigationTask(
            result,
            wallet: wallet
        )
        browserNavigationTask?(cleaner: self)
    }
}

// MARK: BrowserNavigationInteractorOutputProtocol

extension BrowserNavigationPresenter: BrowserNavigationInteractorOutputProtocol {
    func didReceive(walletResult: Result<MetaAccountModel, Error>) {
        switch walletResult {
        case let .success(wallet):
            self.wallet = wallet
        case .failure:
            wallet = nil
        }
    }

    func didReceive(dAppsResult: Result<DAppList, Error>?) {
        guard let dAppsResult else { return }

        if let currentResult = self.dAppsResult {
            if case .success = currentResult, case .failure = dAppsResult {
                return
            }
        }

        self.dAppsResult = dAppsResult
        browserNavigationTask?(cleaner: self)
    }

    func didReceiveFavoriteDapp(changes: [DataProviderChange<DAppFavorite>]) {
        favorites = changes.mergeToDict(favorites ?? [:])
    }
}

// MARK: BrowserNavigationTaskCleaning

extension BrowserNavigationPresenter: BrowserNavigationTaskCleaning {
    func cleanCompletedTask() {
        browserNavigationTask = nil
    }
}

// MARK: BrowserNavigationTaskRouting

/// The task factory's routing closure calls back into the presenter via this hook so
/// the long-lived presenter — not the stateless task factory — owns the routing
/// decision and the warning lifecycle.
extension BrowserNavigationPresenter: BrowserNavigationTaskRouting {
    func route(tab: DAppBrowserTab) {
        routeOrWarn(tab: tab)
    }
}

// MARK: StakingWarningPresentable

extension BrowserNavigationPresenter: StakingWarningPresentable {}

// MARK: DAppStakingWarningViewDelegate

extension BrowserNavigationPresenter: DAppStakingWarningViewDelegate {
    func dappStakingWarningDidSelectContinue(to _: URL) {
        guard let tab = pendingTab else { return }
        pendingTab = nil
        mainAppContainer?.openBrowser(with: tab)
    }

    func dappStakingWarningDidSelectGoToStake() {
        pendingTab = nil
        mainAppContainer?.closeBrowserAndShowStaking()
    }
}
