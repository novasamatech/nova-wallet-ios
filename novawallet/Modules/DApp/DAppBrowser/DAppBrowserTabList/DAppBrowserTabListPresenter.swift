import Foundation
import SoraFoundation

final class DAppBrowserTabListPresenter {
    weak var view: DAppBrowserTabListViewProtocol?
    let wireframe: DAppBrowserTabListWireframeProtocol
    let interactor: DAppBrowserTabListInteractorInputProtocol
    let localizationManager: LocalizationManagerProtocol

    private let dAppList: [DApp]

    private var tabs: [DAppBrowserTab] = []

    init(
        interactor: DAppBrowserTabListInteractorInputProtocol,
        wireframe: DAppBrowserTabListWireframeProtocol,
        dAppList: [DApp],
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.dAppList = dAppList
        self.localizationManager = localizationManager
    }
}

extension DAppBrowserTabListPresenter: DAppBrowserTabListPresenterProtocol {
    func selectTab(with id: UUID) {
        guard let selectedTab = tabs.first(where: { $0.uuid == id }) else {
            return
        }

        let dApp = dAppList.first { $0.url == selectedTab.url }

        wireframe.showTab(
            from: view,
            selectedTab
        )
    }

    func setup() {
        interactor.setup()
    }

    func openNewTab() {
        let newTab = DAppBrowserTab(from: nil)

        wireframe.showTab(
            from: view,
            newTab
        )
    }

    func closeAllTabs() {
        interactor.closeAllTabs()
    }

    func close() {
        wireframe.close(from: view)
    }
}

extension DAppBrowserTabListPresenter: DAppBrowserTabListInteractorOutputProtocol {
    func didReceiveTabs(_ models: [DAppBrowserTab]) {
        tabs = models

        view?.didReceive(models)
    }

    func didReceiveError(_ error: Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        )
    }
}
