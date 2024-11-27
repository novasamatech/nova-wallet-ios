protocol NovaMainAppContainerViewProtocol: ControllerBackedProtocol {}

protocol NovaMainAppContainerPresenterProtocol: AnyObject {
    func openBrowser(tabsCount: Int)
}

protocol NovaMainAppContainerWireframeProtocol: DAppBrowserOpening {}

protocol NovaMainContainerDAppBrowserProtocol: ControllerBackedProtocol {
    func closeTabs()
}
