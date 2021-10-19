protocol NetworkDetailsViewProtocol: ControllerBackedProtocol {}

protocol NetworkDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol NetworkDetailsInteractorInputProtocol: AnyObject {}

protocol NetworkDetailsInteractorOutputProtocol: AnyObject {}

protocol NetworkDetailsWireframeProtocol: AnyObject {}
