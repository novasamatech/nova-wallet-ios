import Foundation

typealias BrowserWidgetContainableView = DAppBrowserWidgetViewProtocol & NovaMainContainerDAppBrowserProtocol

protocol DAppBrowserWidgetViewProtocol: ControllerBackedProtocol {
    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel)
}

protocol DAppBrowserWidgetPresenterProtocol: AnyObject {
    func setup()
    func closeTabs()
}

protocol DAppBrowserWidgetInteractorInputProtocol: AnyObject {
    func setup()
    func closeTabs()
}

protocol DAppBrowserWidgetInteractorOutputProtocol: AnyObject {
    func didReceive(_ browserTabs: [UUID: DAppBrowserTab])
}

protocol DAppBrowserWidgetWireframeProtocol: AnyObject {}
