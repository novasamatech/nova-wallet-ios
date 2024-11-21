import Foundation

protocol DAppBrowserTabListViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModels: [DAppBrowserTab])
}

protocol DAppBrowserTabListPresenterProtocol: AnyObject {
    func setup()
    func selectTab(with id: UUID)
    func openNewTab()
    func closeAllTabs()
    func close()
}

protocol DAppBrowserTabListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DAppBrowserTabListInteractorOutputProtocol: AnyObject {
    func didReceiveTabs(_ models: [DAppBrowserTab])
}

protocol DAppBrowserTabListWireframeProtocol: AnyObject {
    func showTab(
        from view: ControllerBackedProtocol?,
        _ tab: DAppBrowserTab,
        dApp: DApp?
    )

    func close(from view: ControllerBackedProtocol?)
}
