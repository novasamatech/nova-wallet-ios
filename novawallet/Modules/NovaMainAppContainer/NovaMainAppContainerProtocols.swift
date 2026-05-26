protocol NovaMainAppContainerViewProtocol: ControllerBackedProtocol, BrowserNavigationProviding {
    func openBrowser(with tab: DAppBrowserTab?)
    func closeBrowserAndShowStaking()
}

protocol NovaMainAppContainerPresenterProtocol: AnyObject {
    func setup()
}

protocol NovaMainAppContainerWireframeProtocol {
    func showChildViews(on view: ControllerBackedProtocol?)
}
