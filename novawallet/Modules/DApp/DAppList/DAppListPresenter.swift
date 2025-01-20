import Foundation
import SubstrateSdk
import SoraFoundation
import Operation_iOS

final class DAppListPresenter {
    weak var view: DAppListViewProtocol?
    let wireframe: DAppListWireframeProtocol
    let interactor: DAppListInteractorInputProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol

    private var wallet: MetaAccountModel?
    private var dAppsResult: Result<DAppList, Error>?
    private var categoryModels: [DAppCategory] = []
    private var favorites: [String: DAppFavorite]?
    private var hasFavorites: Bool { !(favorites ?? [:]).isEmpty }
    private var hasWalletsListUpdates: Bool = false

    private var dAppOpenTask: (() -> Void)?

    private lazy var iconGenerator = NovaIconGenerator()

    init(
        interactor: DAppListInteractorInputProtocol,
        wireframe: DAppListWireframeProtocol,
        wallet: MetaAccountModel,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideSections() {
        guard let wallet else { return }

        do {
            let sections = viewModelFactory.createDAppSections(
                from: try dAppsResult?.get(),
                favorites: favorites ?? [:],
                wallet: wallet,
                hasWalletsListUpdates: hasWalletsListUpdates,
                locale: selectedLocale
            )

            view?.didReceive(sections)
        } catch {
            let errorSection = viewModelFactory.createErrorSection()
            view?.didReceive([errorSection])
        }
    }

    private func createDAppOpenTask(
        tabProvider: @escaping () -> DAppBrowserTab?,
        routingClosure: @escaping (DAppBrowserTab) -> Void
    ) -> () -> Void {
        { [weak self] in
            guard let tab = tabProvider() else { return }

            routingClosure(tab)

            self?.dAppOpenTask = nil
        }
    }
}

// MARK: DAppListPresenterProtocol

extension DAppListPresenter: DAppListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func refresh() {
        interactor.refresh()
    }

    func activateAccount() {
        wireframe.showWalletSwitch(from: view)
    }

    func activateSearch() {
        wireframe.presentSearch(
            from: view,
            delegate: self
        )
    }

    func activateSettings() {
        wireframe.showSetting(from: view)
    }

    func selectCategory(with id: String) {
        wireframe.presentSearch(
            from: view,
            selectedCategoryId: id,
            delegate: self
        )
    }

    func selectDApp(with id: String) {
        dAppOpenTask = createDAppOpenTask(
            tabProvider: { [weak self] in
                guard
                    let self,
                    let wallet,
                    case let .success(dAppList) = dAppsResult
                else { return nil }

                let tab: DAppBrowserTab? = if let dApp = dAppList.dApps.first(where: { $0.identifier == id }) {
                    DAppBrowserTab(from: dApp, metaId: wallet.metaId)
                } else if let dApp = favorites?[id] {
                    DAppBrowserTab(from: dApp.identifier, metaId: wallet.metaId)
                } else {
                    nil
                }

                return tab
            },
            routingClosure: { [weak self] tab in
                guard let self else { return }

                wireframe.showNewBrowserStack(
                    tab,
                    from: view
                )
            }
        )

        guard
            let wallet,
            case let .success(dAppList) = dAppsResult
        else { return }

        dAppOpenTask?()
    }

    func seeAllFavorites() {
        wireframe.showFavorites(from: view)
    }
}

// MARK: DAppListInteractorOutputProtocol

extension DAppListPresenter: DAppListInteractorOutputProtocol {
    func didReceive(walletResult: Result<MetaAccountModel, Error>) {
        switch walletResult {
        case let .success(wallet):
            self.wallet = wallet
            provideSections()
        case let .failure(error):
            wallet = nil
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    func didReceive(dAppsResult: Result<DAppList, Error>?) {
        view?.didCompleteRefreshing()

        guard dAppsResult != nil else {
            return
        }

        if let currentResult = self.dAppsResult {
            // ignore error if we already loaded some dapps
            guard case .success = currentResult, case .failure = dAppsResult else {
                return
            }
        }

        self.dAppsResult = dAppsResult

        dAppOpenTask?()

        provideSections()
    }

    func didReceiveFavoriteDapp(changes: [DataProviderChange<DAppFavorite>]) {
        favorites = changes.mergeToDict(favorites ?? [:])

        provideSections()
    }

    func didReceiveWalletsState(hasUpdates: Bool) {
        hasWalletsListUpdates = hasUpdates
        provideSections()
    }
}

// MARK: DAppSearchDelegate

extension DAppListPresenter: DAppSearchDelegate {
    func didCompleteDAppSearchResult(_ result: DAppSearchResult) {
        guard let wallet else { return }

        dAppOpenTask = createDAppOpenTask(
            tabProvider: {
                DAppBrowserTab(from: result, metaId: wallet.metaId)
            },
            routingClosure: { [weak self] tab in
                guard let self else { return }

                wireframe.showNewBrowserStack(
                    tab,
                    from: view
                )
            }
        )
        dAppOpenTask?()
    }
}

// MARK: Localizable

extension DAppListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideSections()
        }
    }
}
