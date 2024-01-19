import Foundation

final class ProxySignConfirmationPresenter {
    let view: ControllerBackedProtocol
    let interactor: ProxySignConfirmationInteractorInputProtocol
    let wireframe: ProxySignConfirmationWireframeProtocol
    let completionClosure: ProxySignConfirmationCompletion

    init(
        view: ControllerBackedProtocol,
        interactor: ProxySignConfirmationInteractorInputProtocol,
        wireframe: ProxySignConfirmationWireframeProtocol,
        completionClosure: @escaping ProxySignConfirmationCompletion
    ) {
        self.view = view
        self.interactor = interactor
        self.wireframe = wireframe
        self.completionClosure = completionClosure
    }
}

extension ProxySignConfirmationPresenter: ProxySignConfirmationPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension ProxySignConfirmationPresenter: ProxySignConfirmationInteractorOutputProtocol {
    func didReceive(needsConfirmation: Bool) {
        if needsConfirmation {
            wireframe.showConfirmation(from: view, completionClosure: completionClosure)
        } else {
            completionClosure(true)
        }
    }
}
