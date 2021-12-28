import Foundation
import SubstrateSdk
import SoraFoundation

final class DAppListPresenter {
    weak var view: DAppListViewProtocol?
    let wireframe: DAppListWireframeProtocol
    let interactor: DAppListInteractorInputProtocol
    let viewModelFactory: DAppListViewModelFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    private var accountId: AccountId?
    private var dAppsResult: Result<DAppList, Error>?

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

    private func provideCategoriesState() {
        switch dAppsResult {
        case let .success(dAppList):
            let viewModels = viewModelFactory.createCategories(from: dAppList)
            view?.didReceive(state: .loaded(categories: viewModels))
        case .failure:
            view?.didReceive(state: .error)
        case .none:
            view?.didReceive(state: .loading)
        }
    }
}

extension DAppListPresenter: DAppListPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateAccount() {
        wireframe.showWalletSelection(from: view)
    }

    func filterDApps(forCategory index: Int?) {
        guard case let .success(dAppList) = dAppsResult else {
            return
        }

        let categoryId: String?

        if let categoryIndex = index, categoryIndex < dAppList.categories.count {
            categoryId = dAppList.categories[categoryIndex].identifier
        } else {
            categoryId = nil
        }

        let viewModels = viewModelFactory.createDApps(from: categoryId, dAppList: dAppList)
        view?.didReceiveDApps(viewModels: viewModels)
    }

    func selectDApp(at index: Int) {
        guard case let .success(dAppList) = dAppsResult else {
            return
        }

        let dApp = dAppList.dApps[index]

        wireframe.showBrowser(from: view, for: dApp.url.absoluteString)
    }

    func activateSearch() {
        wireframe.showSearch(from: view, delegate: self)
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
        guard case .success = self.dAppsResult, case .failure = dAppsResult else {
            return
        }

        self.dAppsResult = dAppsResult

        provideCategoriesState()
    }
}

extension DAppListPresenter: DAppSearchDelegate {
    func didCompleteDAppSearchQuery(_ query: String) {
        wireframe.showBrowser(from: view, for: query)
    }
}
