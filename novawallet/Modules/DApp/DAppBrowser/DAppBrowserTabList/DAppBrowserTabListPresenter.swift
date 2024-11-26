import Foundation
import SoraFoundation

final class DAppBrowserTabListPresenter {
    weak var view: DAppBrowserTabListViewProtocol?
    let wireframe: DAppBrowserTabListWireframeProtocol
    let newTabRouter: DAppBrowserNewTabRouterProtocol
    let interactor: DAppBrowserTabListInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    private let viewModelFactory: DAppBrowserTabListViewModelFactoryProtocol

    private var tabs: [DAppBrowserTab] = []

    init(
        interactor: DAppBrowserTabListInteractorInputProtocol,
        wireframe: DAppBrowserTabListWireframeProtocol,
        newTabRouter: DAppBrowserNewTabRouterProtocol,
        viewModelFactory: DAppBrowserTabListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.newTabRouter = newTabRouter
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: Private

private extension DAppBrowserTabListPresenter {
    func provideTabs() {
        let viewModels = viewModelFactory.createViewModels(
            for: tabs,
            locale: localizationManager.selectedLocale
        )

        view?.didReceive(viewModels)
    }
}

// MARK: DAppBrowserTabListPresenterProtocol

extension DAppBrowserTabListPresenter: DAppBrowserTabListPresenterProtocol {
    func selectTab(with id: UUID) {
        guard let selectedTab = tabs.first(where: { $0.uuid == id }) else {
            return
        }

        wireframe.showExistingTab(
            from: view,
            selectedTab
        )
    }

    func setup() {
        interactor.setup()
    }

    func openNewTab() {
        wireframe.presentSearch(
            from: view,
            initialQuery: nil,
            delegate: self
        )
    }

    func closeAllTabs() {
        interactor.closeAllTabs()
    }

    func closeTab(with id: UUID) {
        interactor.closeTab(with: id)
    }

    func close() {
        wireframe.close(from: view)
    }
}

// MARK: DAppBrowserTabListInteractorOutputProtocol

extension DAppBrowserTabListPresenter: DAppBrowserTabListInteractorOutputProtocol {
    func didReceiveTabs(_ models: [DAppBrowserTab]) {
        tabs = models

        provideTabs()
    }

    func didReceiveError(_ error: Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}

// MARK: DAppSearchDelegate

extension DAppBrowserTabListPresenter: DAppSearchDelegate {
    func didCompleteDAppSearchResult(_ result: DAppSearchResult) {
        newTabRouter.process(
            searchResult: result,
            view: view
        )
    }
}
