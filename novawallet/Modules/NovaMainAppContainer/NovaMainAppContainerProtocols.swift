protocol NovaMainAppContainerViewProtocol: ControllerBackedProtocol, BrowserNavigationProviding {
    func openBrowser(with tab: DAppBrowserTab?)
    func minimizeBrowser()
}

protocol NovaMainAppContainerPresenterProtocol: AnyObject {
    func setup()
}

protocol NovaMainAppContainerWireframeProtocol {
    func showChildViews(on view: ControllerBackedProtocol?)
}
