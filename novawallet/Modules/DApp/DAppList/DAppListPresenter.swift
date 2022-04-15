import Foundation
import SubstrateSdk
import SoraFoundation
import RobinHood

final class DAppListPresenter {
    enum CategoryIndex: Equatable {
        case all
        case favorites
        case custom(index: Int, hasFavorites: Bool)

        var selectedIndex: Int {
            switch self {
            case .all:
                return 0
            case .favorites:
                return 1
            case let .custom(index, hasFavorites):
                return hasFavorites ? index + 2 : index + 1
            }
        }

        var customIndex: Int? {
            switch self {
            case .all, .favorites:
                return nil
            case let .custom(index, _):
                return index
            }
        }

        init(uiIndex: Int, hasFavorites: Bool) {
            if uiIndex == 0 {
                self = .all
            } else if uiIndex == 1, hasFavorites {
                self = .favorites
            } else {
                self = hasFavorites ? .custom(index: uiIndex - 2, hasFavorites: hasFavorites)
                    : .custom(index: uiIndex - 1, hasFavorites: hasFavorites)
            }
        }
    }

    weak var view: DAppListViewProtocol?
    let wireframe: DAppListWireframeProtocol
    let interactor: DAppListInteractorInputProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol

    private var accountId: AccountId?
    private var dAppsResult: Result<DAppList, Error>?
    private var categories: [DAppCategory] = []
    private var selectedDApps: [DAppViewModel] = []
    private var favorites: [String: DAppFavorite]?
    private var hasFavorites: Bool { !(favorites ?? [:]).isEmpty }
    private var selectedCategory: CategoryIndex = .all

    private lazy var iconGenerator = NovaIconGenerator()

    init(
        interactor: DAppListInteractorInputProtocol,
        wireframe: DAppListWireframeProtocol,
        viewModelFactory: DAppListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideAccountIcon() {
        guard let accountId = accountId else {
            return
        }

        do {
            let icon = try iconGenerator.generateFromAccountId(accountId)
            view?.didReceiveAccount(icon: icon)
        } catch {
            _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        }
    }

    private func updateCategories() {
        guard let favorites = favorites else {
            return
        }

        if let dAppList = try? dAppsResult?.get() {
            let existingCategories = dAppList.dApps.reduce(into: Set<String>()) { result, dApp in
                dApp.categories.forEach { result.insert($0) }
            }

            let prevCategories = categories
            categories = dAppList.categories.filter { existingCategories.contains($0.identifier) }

            switch selectedCategory {
            case .all:
                selectedDApps = viewModelFactory.createDApps(
                    from: nil,
                    dAppList: dAppList,
                    favorites: favorites
                )
            case .favorites:
                let hasFavorites = !favorites.isEmpty

                if !hasFavorites {
                    selectedCategory = .all

                    selectedDApps = viewModelFactory.createDApps(
                        from: nil,
                        dAppList: dAppList,
                        favorites: favorites
                    )
                } else {
                    selectedCategory = .favorites

                    selectedDApps = viewModelFactory.createFavoriteDApps(from: Array(favorites.values))
                }
            case .custom:
                let maybeSelectedCategory = selectedCategory.customIndex.map { prevCategories[$0] }
                updateCategoriesWhenCustomSelected(
                    for: dAppList,
                    selectedDAppCategory: maybeSelectedCategory
                )
            }

        } else {
            categories = []
            selectedDApps = []
            selectedCategory = .all
        }
    }

    private func updateCategoriesWhenCustomSelected(
        for dAppList: DAppList,
        selectedDAppCategory: DAppCategory?
    ) {
        let maybeNewCategoryIndex = categories.firstIndex { category in
            category.identifier == selectedDAppCategory?.identifier
        }

        selectedCategory = maybeNewCategoryIndex.map {
            CategoryIndex.custom(index: $0, hasFavorites: hasFavorites)
        } ?? .all

        let categoryId = selectedCategory.customIndex.map { categories[$0].identifier }

        selectedDApps = viewModelFactory.createDApps(
            from: categoryId,
            dAppList: dAppList,
            favorites: favorites ?? [:]
        )
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

    private func askDAppRemoval(for identifier: String, name: String) {
        wireframe.showFavoritesRemovalConfirmation(
            from: view,
            name: name,
            locale: selectedLocale
        ) { [weak self] in
            self?.interactor.removeFromFavorites(dAppIdentifier: identifier)
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
        wireframe.showWalletSelection(from: view)
    }

    func activateSearch() {
        wireframe.showSearch(from: view, delegate: self)
    }

    func activateSettings() {
        wireframe.showSetting(from: view)
    }

    func numberOfCategories() -> Int {
        hasFavorites ? categories.count + 2 : categories.count + 1
    }

    func category(at index: Int) -> String {
        let category = CategoryIndex(uiIndex: index, hasFavorites: hasFavorites)

        switch category {
        case .all:
            return R.string.localizable.commonAll(preferredLanguages: selectedLocale.rLanguages)
        case .favorites:
            return R.string.localizable.commonFavorites(preferredLanguages: selectedLocale.rLanguages)
        case let .custom(index, _):
            return categories[index].name
        }
    }

    func selectedCategoryIndex() -> Int {
        selectedCategory.selectedIndex
    }

    func selectCategory(at index: Int) {
        guard let dAppList = try? dAppsResult?.get(), let favorites = favorites else {
            return
        }

        let newCategory = CategoryIndex(uiIndex: index, hasFavorites: hasFavorites)

        guard selectedCategory != newCategory else {
            return
        }

        selectedCategory = newCategory

        switch selectedCategory {
        case .all:
            selectedDApps = viewModelFactory.createDApps(
                from: nil,
                dAppList: dAppList,
                favorites: favorites
            )
        case .favorites:
            selectedDApps = viewModelFactory.createFavoriteDApps(from: Array(favorites.values))
        case let .custom(index, _):
            let categoryId = categories[index].identifier
            selectedDApps = viewModelFactory.createDApps(
                from: categoryId,
                dAppList: dAppList,
                favorites: favorites
            )
        }

        view?.didReceive(state: .loaded)
    }

    func numberOfDApps() -> Int {
        selectedDApps.count
    }

    func dApp(at index: Int) -> DAppViewModel {
        selectedDApps[index]
    }

    func selectDApp(at index: Int) {
        guard case let .success(dAppList) = dAppsResult else {
            return
        }

        let dAppViewModel = selectedDApps[index]

        switch dAppViewModel.identifier {
        case let .index(value):
            let dApp = dAppList.dApps[value]

            wireframe.showBrowser(from: view, for: .dApp(model: dApp))

        case let .key(value):
            if let dapp = favorites?[value] {
                wireframe.showBrowser(from: view, for: .query(string: dapp.identifier))
            }
        }
    }

    func toogleFavoriteForDApp(at index: Int) {
        guard case let .success(dAppList) = dAppsResult else {
            return
        }

        let dAppViewModel = selectedDApps[index]

        switch dAppViewModel.identifier {
        case let .index(value):
            let dApp = dAppList.dApps[value]
            let identifier = dApp.identifier

            if favorites?[identifier] != nil {
                askDAppRemoval(for: identifier, name: dAppViewModel.name)
            } else {
                interactor.addToFavorites(dApp: dApp)
            }

        case let .key(value):
            if let dapp = favorites?[value] {
                let name = viewModelFactory.createFavoriteDAppName(from: dapp)
                askDAppRemoval(for: dapp.identifier, name: name)
            }
        }
    }
}

extension DAppListPresenter: DAppListInteractorOutputProtocol {
    func didReceive(accountIdResult: Result<AccountId, Error>) {
        switch accountIdResult {
        case let .success(accountId):
            self.accountId = accountId
            provideAccountIcon()
        case let .failure(error):
            accountId = nil
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

        updateCategories()
        updateState()
    }

    func didReceiveFavoriteDapp(changes: [DataProviderChange<DAppFavorite>]) {
        favorites = changes.mergeToDict(favorites ?? [:])

        updateCategories()
        updateState()
    }
}

extension DAppListPresenter: DAppSearchDelegate {
    func didCompleteDAppSearchResult(_ result: DAppSearchResult) {
        wireframe.showBrowser(from: view, for: result)
    }
}

extension DAppListPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateState()
        }
    }
}
