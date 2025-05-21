protocol PaySpendViewProtocol: ControllerBackedProtocol {}

protocol PaySpendPresenterProtocol: AnyObject {
    func setup()
}

protocol PaySpendInteractorInputProtocol: AnyObject {}

protocol PaySpendInteractorOutputProtocol: AnyObject {}

protocol PaySpendWireframeProtocol: AnyObject {}
