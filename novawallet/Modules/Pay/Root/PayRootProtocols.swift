protocol PayRootViewProtocol: ControllerBackedProtocol {}

protocol PayChildViewProtocol: ControllerBackedProtocol {
    func bind()
    func unbind()
}

protocol PayRootPresenterProtocol: AnyObject {
    func setup()
}

protocol PayRootInteractorInputProtocol: AnyObject {}

protocol PayRootInteractorOutputProtocol: AnyObject {}

protocol PayRootWireframeProtocol: AnyObject {}
