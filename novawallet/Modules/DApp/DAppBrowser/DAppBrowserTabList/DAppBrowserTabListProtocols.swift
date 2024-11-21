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
    func closeAllTabs()
}

protocol DAppBrowserTabListInteractorOutputProtocol: AnyObject {
    func didReceiveTabs(_ models: [DAppBrowserTab])
    func didReceiveError(_ error: Error)
}

protocol DAppBrowserTabListWireframeProtocol: AnyObject, AlertPresentable, ErrorPresentable {
    func showTab(
        from view: ControllerBackedProtocol?,
        _ tab: DAppBrowserTab
    )

    func close(from view: ControllerBackedProtocol?)
}
