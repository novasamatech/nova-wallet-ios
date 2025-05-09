protocol NavigationRootViewProtocol: ControllerBackedProtocol {}

protocol NavigationRootPresenterProtocol: AnyObject {
    func setup()
}

protocol NavigationRootInteractorInputProtocol: AnyObject {}

protocol NavigationRootInteractorOutputProtocol: AnyObject {}

protocol NavigationRootWireframeProtocol: AnyObject {}
