import Foundation

final class DelegatedSignConfirmationPresenter {
    let view: ControllerBackedProtocol
    let interactor: DelegatedSignConfirmationInteractorInputProtocol
    let wireframe: DelegatedSignConfirmationWireframeProtocol
    let completionClosure: DelegatedSignConfirmationCompletion

    init(
        view: ControllerBackedProtocol,
        interactor: DelegatedSignConfirmationInteractorInputProtocol,
        wireframe: DelegatedSignConfirmationWireframeProtocol,
        completionClosure: @escaping DelegatedSignConfirmationCompletion
    ) {
        self.view = view
        self.interactor = interactor
        self.wireframe = wireframe
        self.completionClosure = completionClosure
    }
}

extension DelegatedSignConfirmationPresenter: DelegatedSignConfirmationPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension DelegatedSignConfirmationPresenter: DelegatedSignConfirmationInteractorOutputProtocol {
    func didReceive(needsConfirmation: Bool) {
        if needsConfirmation {
            wireframe.showConfirmation(from: view, completionClosure: completionClosure)
        } else {
            completionClosure(true)
        }
    }
}
