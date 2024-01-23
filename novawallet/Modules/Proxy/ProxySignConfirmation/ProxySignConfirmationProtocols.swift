import Foundation

typealias ProxySignConfirmationCompletion = (Bool) -> Void

protocol ProxySignConfirmationPresenterProtocol: AnyObject {
    func setup()
}

protocol ProxySignConfirmationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ProxySignConfirmationInteractorOutputProtocol: AnyObject {
    func didReceive(needsConfirmation: Bool)
}

protocol ProxySignConfirmationWireframeProtocol {
    func showConfirmation(
        from view: ControllerBackedProtocol,
        completionClosure: @escaping ProxySignConfirmationCompletion
    )
}
