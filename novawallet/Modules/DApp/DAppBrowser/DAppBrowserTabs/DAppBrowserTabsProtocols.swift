import Foundation

protocol DAppBrowserTabsViewProtocol: ControllerBackedProtocol {
    func didReceive(_ viewModels: [DAppBrowserTabModel])
}

protocol DAppBrowserTabsPresenterProtocol: AnyObject {
    func setup()
    func selectTab(with id: UUID)
}

protocol DAppBrowserTabsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DAppBrowserTabsInteractorOutputProtocol: AnyObject {
    func didReceiveTabs(_ models: [DAppBrowserTabModel])
}

protocol DAppBrowserTabsWireframeProtocol: AnyObject {
    func close(view: DAppBrowserTabsViewProtocol?)
}
