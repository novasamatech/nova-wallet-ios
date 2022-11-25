import Foundation

protocol ReferendumFullDescriptionViewProtocol: ControllerBackedProtocol {
    func didReceive(title: String, description: String)
}

protocol ReferendumFullDescriptionPresenterProtocol: AnyObject {
    func setup()
    func open(url: URL)
}

protocol ReferendumFullDescriptionInteractorInputProtocol: AnyObject {}

protocol ReferendumFullDescriptionInteractorOutputProtocol: AnyObject {}

protocol ReferendumFullDescriptionWireframeProtocol: WebPresentable {}
