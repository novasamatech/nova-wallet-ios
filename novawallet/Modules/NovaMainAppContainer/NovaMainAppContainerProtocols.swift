protocol NovaMainAppContainerViewProtocol: AnyObject {}

protocol NovaMainAppContainerPresenterProtocol: AnyObject {
    func setup()
}

protocol NovaMainAppContainerInteractorInputProtocol: AnyObject {}

protocol NovaMainAppContainerInteractorOutputProtocol: AnyObject {}

protocol NovaMainAppContainerWireframeProtocol: AnyObject {}

protocol NovaMainContainerDAppBrowserProtocol: ControllerBackedProtocol {
    func closeTabs()
}
