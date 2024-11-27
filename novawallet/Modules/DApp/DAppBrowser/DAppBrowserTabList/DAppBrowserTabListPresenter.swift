import Foundation
import SoraFoundation

final class DAppBrowserTabListPresenter {
    weak var view: DAppBrowserTabListViewProtocol?
    let wireframe: DAppBrowserTabListWireframeProtocol
    let interactor: DAppBrowserTabListInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    private let viewModelFactory: DAppBrowserTabListViewModelFactoryProtocol

    private var tabs: [DAppBrowserTab] = []

    init(
        interactor: DAppBrowserTabListInteractorInputProtocol,
        wireframe: DAppBrowserTabListWireframeProtocol,
        viewModelFactory: DAppBrowserTabListViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
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

        wireframe.showInExistingBrowserStack(
            selectedTab,
            from: view
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
        guard let tab = DAppBrowserTab(from: result) else {
            return
        }

        tabs.append(tab)
        provideTabs()

        wireframe.showInExistingBrowserStack(
            tab,
            from: view
        )
    }
}
