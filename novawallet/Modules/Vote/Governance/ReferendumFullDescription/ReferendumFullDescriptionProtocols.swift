protocol ReferendumFullDescriptionViewProtocol: ControllerBackedProtocol {
    func didReceive(title: String, description: String)
}

protocol ReferendumFullDescriptionPresenterProtocol: AnyObject {
    func setup()
}

protocol ReferendumFullDescriptionInteractorInputProtocol: AnyObject {}

protocol ReferendumFullDescriptionInteractorOutputProtocol: AnyObject {}

protocol ReferendumFullDescriptionWireframeProtocol: AnyObject {}
