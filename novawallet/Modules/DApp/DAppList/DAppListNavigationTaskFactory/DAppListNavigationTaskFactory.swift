import Foundation

protocol DAppListNavigationTaskFactoryProtocol {
    func createDAppNavigationTaskById(
        _ dAppId: String,
        wallet: MetaAccountModel?,
        favoritesProvider: @escaping () -> [String: DAppFavorite]?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> DAppListNavigationTask

    func createDAppNavigationTaskByModel(
        _ model: DAppNavigation,
        wallet: MetaAccountModel?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> DAppListNavigationTask

    func createSearchResultNavigationTask(
        _ result: DAppSearchResult,
        wallet: MetaAccountModel
    ) -> DAppListNavigationTask
}

final class DAppListNavigationTaskFactory {
    private let wireframe: DAppListWireframeProtocol

    init(wireframe: DAppListWireframeProtocol) {
        self.wireframe = wireframe
    }
}

// MARK: DAppListNavigationTaskFactoryProtocol

extension DAppListNavigationTaskFactory: DAppListNavigationTaskFactoryProtocol {
    func createDAppNavigationTaskById(
        _ dAppId: String,
        wallet: MetaAccountModel?,
        favoritesProvider: @escaping () -> [String: DAppFavorite]?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> DAppListNavigationTask {
        DAppListNavigationTask(
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
                    nil
                }

                return tab
            },
            routingClosure: { [weak self] tab, view in
                guard let self else { return }

                wireframe.showNewBrowserStack(
                    tab,
                    from: view
                )
            }
        )
    }

    func createDAppNavigationTaskByModel(
        _ model: DAppNavigation,
        wallet: MetaAccountModel?,
        dAppResultProvider: @escaping () -> Result<DAppList, Error>?
    ) -> DAppListNavigationTask {
        DAppListNavigationTask(
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
            routingClosure: { [weak self] tab, view in
                guard let self else { return }

                wireframe.showNewBrowserStack(tab, from: view)
            }
        )
    }

    func createSearchResultNavigationTask(
        _ result: DAppSearchResult,
        wallet: MetaAccountModel
    ) -> DAppListNavigationTask {
        DAppListNavigationTask(
            tabProvider: {
                DAppBrowserTab(from: result, metaId: wallet.metaId)
            },
            routingClosure: { [weak self] tab, view in
                guard let self else { return }

                wireframe.showNewBrowserStack(
                    tab,
                    from: view
                )
            }
        )
    }
}
