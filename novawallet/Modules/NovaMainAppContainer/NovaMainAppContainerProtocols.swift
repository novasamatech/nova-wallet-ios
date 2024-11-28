protocol NovaMainAppContainerViewProtocol: ControllerBackedProtocol {
    func openBrowser(with tab: DAppBrowserTab?)
}

protocol NovaMainAppContainerPresenterProtocol: AnyObject {
    func setup()
}

protocol NovaMainAppContainerWireframeProtocol {
    func showChildViews(on view: ControllerBackedProtocol?)
}
