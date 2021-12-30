import Foundation
import SubstrateSdk
import SoraFoundation

final class DAppListPresenter {
    enum CategoryIndex: Equatable {
        case all
        case custom(index: Int)

        var selectedIndex: Int {
            switch self {
            case .all:
                return 0
            case let .custom(index):
                return index + 1
            }
        }

        var customIndex: Int? {
            switch self {
            case .all:
                return nil
            case let .custom(index):
                return index
            }
        }

        init(uiIndex: Int) {
            if uiIndex == 0 {
                self = .all
            } else {
                self = .custom(index: uiIndex - 1)
            }
        }
    }

    weak var view: DAppListViewProtocol?
    let wireframe: DAppListWireframeProtocol
    let interactor: DAppListInteractorInputProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var accountId: AccountId?
    private var dAppsResult: Result<DAppList, Error>?
    private var categories: [DAppCategory] = []
    private var selectedDApps: [DAppViewModel] = []
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
            _ = wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)
        }
    }

    private func updateCategories() {
        if let dAppList = try? dAppsResult?.get() {
            let existingCategories = dAppList.dApps.reduce(into: Set<String>()) { result, dApp in
                dApp.categories.forEach { result.insert($0) }
            }

            let maybeSelectedCategory = selectedCategory.customIndex.map { categories[$0] }
            categories = dAppList.categories.filter { existingCategories.contains($0.identifier) }

            let maybeNewCategoryIndex = categories.firstIndex { category in
                category.identifier == maybeSelectedCategory?.identifier
            }

            selectedCategory = maybeNewCategoryIndex.map { CategoryIndex.custom(index: $0) } ?? .all

            let categoryId = selectedCategory.customIndex.map { categories[$0].identifier }

            selectedDApps = viewModelFactory.createDApps(from: categoryId, dAppList: dAppList)
        } else {
            categories = []
            selectedDApps = []
            selectedCategory = .all
        }
    }

    private func updateState() {
        switch dAppsResult {
        case .success:
            view?.didReceive(state: .loaded)
        case .failure:
            view?.didReceive(state: .error)
        case .none:
            view?.didReceive(state: .loading)
        }
    }
}

extension DAppListPresenter: DAppListPresenterProtocol {
    func setup() {
        updateState()

        interactor.setup()
    }

    func activateAccount() {
        wireframe.showWalletSelection(from: view)
    }

    func activateSearch() {
        wireframe.showSearch(from: view, delegate: self)
    }

    func numberOfCategories() -> Int {
        categories.count + 1
    }

    func category(at index: Int) -> String {
        let category = CategoryIndex(uiIndex: index)

        switch category {
        case .all:
            return "All"
        case let .custom(index):
            return categories[index].name
        }
    }

    func selectedCategoryIndex() -> Int {
        selectedCategory.selectedIndex
    }

    func selectCategory(at index: Int) {
        guard let dAppList = try? dAppsResult?.get() else {
            return
        }

        let newCategory = CategoryIndex(uiIndex: index)

        guard selectedCategory != newCategory else {
            return
        }

        selectedCategory = newCategory

        if let categoryIndex = selectedCategory.customIndex {
            let categoryId = categories[categoryIndex].identifier
            selectedDApps = viewModelFactory.createDApps(from: categoryId, dAppList: dAppList)
        } else {
            selectedDApps = viewModelFactory.createDApps(from: nil, dAppList: dAppList)
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
        let dApp = dAppList.dApps[dAppViewModel.index]

        wireframe.showBrowser(from: view, for: dApp.url.absoluteString)
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
            _ = wireframe.present(error: error, from: view, locale: localizationManager.selectedLocale)
        }
    }

    func didReceive(dAppsResult: Result<DAppList, Error>) {
        // ignore if we already loaded some dapps

        if let currentResult = self.dAppsResult {
            guard case .success = currentResult, case .failure = dAppsResult else {
                return
            }
        }

        self.dAppsResult = dAppsResult

        updateCategories()
        updateState()
    }
}

extension DAppListPresenter: DAppSearchDelegate {
    func didCompleteDAppSearchQuery(_ query: String) {
        wireframe.showBrowser(from: view, for: query)
    }
}
