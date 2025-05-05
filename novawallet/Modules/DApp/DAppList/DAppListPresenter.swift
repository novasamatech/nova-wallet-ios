import Foundation
import SubstrateSdk
import Foundation_iOS
import Operation_iOS

final class DAppListPresenter: BannersModuleInputOwnerProtocol {
    weak var view: DAppListViewProtocol?
    weak var bannersModule: BannersModuleInputProtocol?

    let wireframe: DAppListWireframeProtocol
    let interactor: DAppListInteractorInputProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol

    private var wallet: MetaAccountModel?
    private var dAppsResult: Result<DAppList, Error>?
    private var categoryModels: [DAppCategory] = []
    private var favorites: [String: DAppFavorite]?
    private var hasFavorites: Bool { !(favorites ?? [:]).isEmpty }
    private var randomizationSeed: Int = 1
    private var hasWalletsListUpdates: Bool = false

    private lazy var iconGenerator = NovaIconGenerator()

    init(
        interactor: DAppListInteractorInputProtocol,
        wireframe: DAppListWireframeProtocol,
        initialWallet: MetaAccountModel,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
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
                bannersState: bannersModule?.bannersState ?? .unavailable,
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

        if bannersModule?.locale != selectedLocale {
            bannersModule?.updateLocale(selectedLocale)
        }
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
        wireframe.openBrowser(with: id)
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
        wireframe.openBrowser(with: result)
    }
}

// MARK: BannersModuleOutputProtocol

extension DAppListPresenter: BannersModuleOutputProtocol {
    func didReceiveBanners(state _: BannersState) {
        provideSections()
    }

    func didReceive(_ error: any Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
    }

    func didUpdateContent(state _: BannersState) {
        provideSections()
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
