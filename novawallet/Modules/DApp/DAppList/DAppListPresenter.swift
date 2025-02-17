import Foundation
import SubstrateSdk
import SoraFoundation
import Operation_iOS

final class DAppListPresenter: BannersModuleInputOwnerProtocol {
    weak var view: DAppListViewProtocol?
    weak var bannersModule: BannersModuleInputProtocol?

    let wireframe: DAppListWireframeProtocol
    let interactor: DAppListInteractorInputProtocol
    let browserNavigationTaskFactory: DAppListNavigationTaskFactoryProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol

    private var wallet: MetaAccountModel?
    private var dAppsResult: Result<DAppList, Error>?
    private var categoryModels: [DAppCategory] = []
    private var favorites: [String: DAppFavorite]?
    private var hasFavorites: Bool { !(favorites ?? [:]).isEmpty }
    private var randomizationSeed: Int = 1
    private var hasWalletsListUpdates: Bool = false

    private var dAppNavigationTask: DAppListNavigationTask?

    private lazy var iconGenerator = NovaIconGenerator()

    init(
        interactor: DAppListInteractorInputProtocol,
        wireframe: DAppListWireframeProtocol,
        browserNavigationTaskFactory: DAppListNavigationTaskFactoryProtocol,
        initialWallet: MetaAccountModel,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.browserNavigationTaskFactory = browserNavigationTaskFactory
        wallet = initialWallet
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideSections() {
        do {
            let params = DAppListViewModelFactory.ListSectionsParams(
                randomizationSeed: randomizationSeed,
                hasWalletsListUpdates: hasWalletsListUpdates
            )
            let sections = viewModelFactory.createDAppSections(
                from: try dAppsResult?.get(),
                favorites: favorites ?? [:],
                wallet: wallet,
                params: params,
                bannersAvailable: bannersModule?.bannersAvailable ?? false,
                locale: selectedLocale
            )

            view?.didReceive(sections)
        } catch {
            let errorSection = viewModelFactory.createErrorSection()
            view?.didReceive([errorSection])
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
        bannersModule?.refresh()
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
        dAppNavigationTask = browserNavigationTaskFactory.createDAppNavigationTaskById(
            id,
            wallet: wallet,
            favoritesProvider: { [weak self] in self?.favorites },
            dAppResultProvider: { [weak self] in self?.dAppsResult }
        )

        dAppNavigationTask?(
            cleaner: self,
            view: view
        )
    }

    func provideNavigation(for model: DAppNavigation) {
        guard let wallet else {
            return
        }

        dAppNavigationTask = browserNavigationTaskFactory.createDAppNavigationTaskByModel(
            model,
            wallet: wallet,
            dAppResultProvider: { [weak self] in self?.dAppsResult }
        )

        dAppNavigationTask?(
            cleaner: self,
            view: view
        )
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
            if case .success = currentResult, case .failure = dAppsResult {
                return
            }
        }

        self.dAppsResult = dAppsResult
        randomizationSeed = Int.random(in: 1 ..< 100)

        dAppNavigationTask?(
            cleaner: self,
            view: view
        )

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

        let navigationTask = browserNavigationTaskFactory.createSearchResultNavigationTask(
            result,
            wallet: wallet
        )

        navigationTask(
            cleaner: self,
            view: view
        )
    }
}

// MARK: BannersModuleOutputProtocol

extension DAppListPresenter: BannersModuleOutputProtocol {
    func didReceiveBanners(available _: Bool) {
        provideSections()
    }

    func didReceive(_ error: any Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
    }

    func didUpdateContentLocale() {
        provideSections()
    }
}

// MARK: DAppListNavigationTaskCleaning

extension DAppListPresenter: DAppListNavigationTaskCleaning {
    func cleanCompletedTask() {
        dAppNavigationTask = nil
    }
}

// MARK: Localizable

extension DAppListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideSections()
            bannersModule?.updateLocale(selectedLocale)
        }
    }
}
