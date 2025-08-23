import Foundation

typealias DelegatedSignConfirmationCompletion = (Bool) -> Void

protocol DelegatedSignConfirmationPresenterProtocol: AnyObject {
    func setup()
}

protocol DelegatedSignConfirmationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DelegatedSignConfirmationInteractorOutputProtocol: AnyObject {
    func didReceive(needsConfirmation: Bool)
}

protocol DelegatedSignConfirmationWireframeProtocol {
    func showConfirmation(
        from view: ControllerBackedProtocol,
        completionClosure: @escaping DelegatedSignConfirmationCompletion
    )
}
