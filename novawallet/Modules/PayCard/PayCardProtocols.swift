protocol PayCardViewProtocol: ControllerBackedProtocol {}

protocol PayCardPresenterProtocol: AnyObject {
    func setup()
}

protocol PayCardInteractorInputProtocol: AnyObject {}

protocol PayCardInteractorOutputProtocol: AnyObject {}

protocol PayCardWireframeProtocol: AnyObject {}
