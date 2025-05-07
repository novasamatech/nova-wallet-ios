protocol PayRootViewProtocol: ControllerBackedProtocol {}

protocol PayRootPresenterProtocol: AnyObject {
    func setup()
}

protocol PayRootInteractorInputProtocol: AnyObject {}

protocol PayRootInteractorOutputProtocol: AnyObject {}

protocol PayRootWireframeProtocol: AnyObject {}
