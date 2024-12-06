import Foundation
import SubstrateSdk
import SoraFoundation
import Operation_iOS

final class DAppListPresenter {
    weak var view: DAppListViewProtocol?
    let wireframe: DAppListWireframeProtocol
    let interactor: DAppListInteractorInputProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol
    let categoryViewModelFactory: DAppCategoryViewModelFactoryProtocol

    private var wallet: MetaAccountModel?
    private var dAppsResult: Result<DAppList, Error>?
    private var categoryModels: [DAppCategory] = []
    private var favorites: [String: DAppFavorite]?
    private var hasFavorites: Bool { !(favorites ?? [:]).isEmpty }
    private var hasWalletsListUpdates: Bool = false

    private lazy var iconGenerator = NovaIconGenerator()

    init(
        interactor: DAppListInteractorInputProtocol,
        wireframe: DAppListWireframeProtocol,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        categoryViewModelFactory: DAppCategoryViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.categoryViewModelFactory = categoryViewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideSections() {
        guard
            case let .success(dAppList) = dAppsResult,
            let wallet
        else {
            return
        }

        let sections = viewModelFactory.createDAppSections(
            from: dAppList,
            favorites: favorites ?? [:],
            wallet: wallet,
            hasWalletsListUpdates: hasWalletsListUpdates,
            locale: selectedLocale
        )

        view?.didReceive(sections)
    }

    private func updateState() {
        if favorites != nil {
            switch dAppsResult {
            case .success:
                view?.didReceive(state: .loaded)
            case .failure:
                view?.didReceive(state: .error)
            case .none:
                view?.didReceive(state: .loading)
            }
        } else {
            view?.didReceive(state: .loading)
        }
    }
}

extension DAppListPresenter: DAppListPresenterProtocol {
    func setup() {
        updateState()

        interactor.setup()
    }

    func refresh() {
        interactor.refresh()
    }

    func activateAccount() {
        wireframe.showWalletSwitch(from: view)
    }

    func activateSearch() {
        wireframe.showSearch(from: view, delegate: self)
    }

    func activateSettings() {
        wireframe.showSetting(from: view)
    }

    func numberOfCategories() -> Int {
        hasFavorites ? categoryModels.count + 2 : categoryModels.count + 1
    }

    func selectCategory(with _: String) {
        guard
            case let .success(dAppList) = dAppsResult,
            let favorites = favorites
        else {
            return
        }

        // TODO: Show search with selected category
    }

    func selectDApp(with id: String) {
        guard case let .success(dAppList) = dAppsResult else { return }

        let tab: DAppBrowserTab? = if let dApp = dAppList.dApps.first(where: { $0.identifier == id }) {
            DAppBrowserTab(from: dApp)
        } else if let dApp = favorites?[id] {
            DAppBrowserTab(from: dApp.identifier)
        } else {
            nil
        }

        guard let tab else { return }

        wireframe.showNewBrowserStack(
            tab,
            from: view
        )
    }

    func seeAllFavorites() {
        print("SEE_ALL_FAVORITES")
    }
}

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

        provideSections()
        updateState()
    }

    func didReceiveFavoriteDapp(changes: [DataProviderChange<DAppFavorite>]) {
        favorites = changes.mergeToDict(favorites ?? [:])

        provideSections()
        updateState()
    }

    func didReceiveWalletsState(hasUpdates: Bool) {
        hasWalletsListUpdates = hasUpdates
        provideSections()
    }
}

extension DAppListPresenter: DAppSearchDelegate {
    func didCompleteDAppSearchResult(_ result: DAppSearchResult) {
        guard let tab = DAppBrowserTab(from: result) else {
            return
        }

        wireframe.showNewBrowserStack(
            tab,
            from: view
        )
    }
}

extension DAppListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateState()
        }
    }
}
