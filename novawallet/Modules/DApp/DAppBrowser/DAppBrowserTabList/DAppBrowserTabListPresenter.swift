import Foundation
import Foundation_iOS

final class DAppBrowserTabListPresenter {
    weak var view: DAppBrowserTabListViewProtocol?
    let wireframe: DAppBrowserTabListWireframeProtocol
    let interactor: DAppBrowserTabListInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    let metaId: MetaAccountModel.Id

    private let viewModelFactory: DAppBrowserTabListViewModelFactoryProtocol

    private var tabs: [DAppBrowserTab] = []

    init(
        interactor: DAppBrowserTabListInteractorInputProtocol,
        wireframe: DAppBrowserTabListWireframeProtocol,
        viewModelFactory: DAppBrowserTabListViewModelFactoryProtocol,
        metaId: MetaAccountModel.Id,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.metaId = metaId
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

        wireframe.showTab(
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
        if tabs.count > 1 {
            wireframe.presentCloseTabsAlert(
                from: view,
                with: localizationManager.selectedLocale
            ) { [weak self] in
                self?.interactor.closeAllTabs()
            }
        } else {
            interactor.closeAllTabs()
        }
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
        if !tabs.isEmpty, models.isEmpty {
            wireframe.close(from: view)
            return
        }

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
        guard let tab = DAppBrowserTab(from: result, metaId: metaId) else {
            return
        }

        tabs.append(tab)
        provideTabs()

        wireframe.showTab(
            tab,
            from: view
        )
    }
}
