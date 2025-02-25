protocol NovaMainAppContainerViewProtocol: ControllerBackedProtocol {
    func openBrowser(with tab: DAppBrowserTab?)
}

protocol NovaMainAppContainerInteractorInputProtocol: AnyObject {
    func setup()
}

protocol NovaMainAppContainerPresenterProtocol: AnyObject {
    func setup()
}

protocol NovaMainAppContainerWireframeProtocol {
    func showChildViews(on view: ControllerBackedProtocol?)
}
