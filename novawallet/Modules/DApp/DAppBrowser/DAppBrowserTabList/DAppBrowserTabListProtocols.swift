import Foundation

protocol DAppBrowserTabListViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModels: [DAppBrowserTab])
}

protocol DAppBrowserTabListPresenterProtocol: AnyObject {
    func setup()
    func selectTab(with id: UUID)
}

protocol DAppBrowserTabListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DAppBrowserTabListInteractorOutputProtocol: AnyObject {
    func didReceiveTabs(_ models: [DAppBrowserTab])
}

protocol DAppBrowserTabListWireframeProtocol: AnyObject {}
