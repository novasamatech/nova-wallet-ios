import Foundation

typealias BrowserWidgetContainableView = BrowserWidgetViewProtocol & NovaMainContainerDAppBrowserProtocol

protocol BrowserWidgetViewProtocol: ControllerBackedProtocol {
    func didReceive(_ browserWidgetViewModel: DAppBrowserWidgetViewModel)
}

protocol BrowserWidgetPresenterProtocol: AnyObject {
    func setup()
    func closeTabs()
}

protocol BrowserWidgetInteractorInputProtocol: AnyObject {
    func setup()
    func closeTabs()
}

protocol BrowserWidgetInteractorOutputProtocol: AnyObject {
    func didReceive(_ browserTabs: [UUID: DAppBrowserTabModel])
}

protocol BrowserWidgetWireframeProtocol: AnyObject {}
