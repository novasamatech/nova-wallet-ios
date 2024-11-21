import Foundation

final class DAppBrowserTabListPresenter {
    weak var view: DAppBrowserTabListViewProtocol?
    let wireframe: DAppBrowserTabListWireframeProtocol
    let interactor: DAppBrowserTabListInteractorInputProtocol

    private let dAppList: [DApp]

    private var tabs: [DAppBrowserTab] = []

    init(
        interactor: DAppBrowserTabListInteractorInputProtocol,
        wireframe: DAppBrowserTabListWireframeProtocol,
        dAppList: [DApp]
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.dAppList = dAppList
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
            selectedTab,
            dApp: dApp
        )
    }

    func setup() {
        interactor.setup()
    }
}

extension DAppBrowserTabListPresenter: DAppBrowserTabListInteractorOutputProtocol {
    func didReceiveTabs(_ models: [DAppBrowserTab]) {
        tabs = models

        view?.didReceive(models)
    }
}
