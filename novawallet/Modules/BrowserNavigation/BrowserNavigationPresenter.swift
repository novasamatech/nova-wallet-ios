import Foundation
import Operation_iOS

final class BrowserNavigationPresenter {
    let interactor: BrowserNavigationInteractorInputProtocol
    let browserNavigationTaskFactory: BrowserNavigationTaskFactoryProtocol

    private var wallet: MetaAccountModel?
    private var dAppsResult: Result<DAppList, Error>?
    private var categoryModels: [DAppCategory] = []
    private var favorites: [String: DAppFavorite]?

    private var browserNavigationTask: BrowserNavigationTask?

    init(
        interactor: BrowserNavigationInteractorInputProtocol,
        browserNavigationTaskFactory: BrowserNavigationTaskFactoryProtocol
    ) {
        self.interactor = interactor
        self.browserNavigationTaskFactory = browserNavigationTaskFactory
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
        guard let dAppsResult else {
            return
        }

        if let currentResult = self.dAppsResult {
            // ignore error if we already loaded some dapps
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
