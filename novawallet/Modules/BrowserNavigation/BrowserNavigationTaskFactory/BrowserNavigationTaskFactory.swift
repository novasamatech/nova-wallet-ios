import Foundation

protocol BrowserNavigationTaskFactoryProtocol {
    func createDAppNavigationTaskById(
        _ dAppId: String,
        wallet: MetaAccountModel?,
        favoritesProvider: @escaping () -> [String: DAppFavorite]?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> BrowserNavigationTask

    func createDAppNavigationTaskByModel(
        _ model: DAppNavigation,
        wallet: MetaAccountModel?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> BrowserNavigationTask

    func createSearchResultNavigationTask(
        _ result: DAppSearchResult,
        wallet: MetaAccountModel
    ) -> BrowserNavigationTask
}

final class BrowserNavigationTaskFactory {
    weak var mainAppContainer: NovaMainAppContainerViewProtocol?

    init(mainAppContainer: NovaMainAppContainerViewProtocol) {
        self.mainAppContainer = mainAppContainer
    }
}

// MARK: BrowserNavigationTaskFactoryProtocol

extension BrowserNavigationTaskFactory: BrowserNavigationTaskFactoryProtocol {
    func createDAppNavigationTaskById(
        _ dAppId: String,
        wallet: MetaAccountModel?,
        favoritesProvider: @escaping () -> [String: DAppFavorite]?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> BrowserNavigationTask {
        BrowserNavigationTask(
            tabProvider: {
                guard
                    let wallet,
                    case let .success(dAppList) = dAppResultProvider()
                else { return nil }

                let tab: DAppBrowserTab? = if let dApp = dAppList.dApps.first(where: { $0.identifier == dAppId }) {
                    DAppBrowserTab(from: dApp, metaId: wallet.metaId)
                } else if let dApp = favoritesProvider()?[dAppId] {
                    DAppBrowserTab(from: dApp.identifier, metaId: wallet.metaId)
                } else {
                    DAppBrowserTab(from: dAppId, metaId: wallet.metaId)
                }

                return tab
            },
            routingClosure: { [weak self] tab in
                guard let self else { return }

                mainAppContainer?.openBrowser(with: tab)
            }
        )
    }

    func createDAppNavigationTaskByModel(
        _ model: DAppNavigation,
        wallet: MetaAccountModel?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> BrowserNavigationTask {
        BrowserNavigationTask(
            tabProvider: {
                guard
                    let wallet,
                    case let .success(dAppList) = dAppResultProvider(),
                    let dApp = dAppList.dApps.first(
                        where: { URL.hostsEqual($0.url, model.url) }
                    )
                else {
                    return nil
                }

                let searchResult: DAppSearchResult = if dApp.url == model.url {
                    .dApp(model: dApp)
                } else {
                    .query(string: model.url.absoluteString)
                }

                return DAppBrowserTab(from: searchResult, metaId: wallet.metaId)
            },
            routingClosure: { [weak self] tab in
                guard let self else { return }

                mainAppContainer?.openBrowser(with: tab)
            }
        )
    }

    func createSearchResultNavigationTask(
        _ result: DAppSearchResult,
        wallet: MetaAccountModel
    ) -> BrowserNavigationTask {
        BrowserNavigationTask(
            tabProvider: {
                DAppBrowserTab(from: result, metaId: wallet.metaId)
            },
            routingClosure: { [weak self] tab in
                guard let self else { return }

                mainAppContainer?.openBrowser(with: tab)
            }
        )
    }
}
