import Foundation

final class DelegatedSignValidationPresenter {
    let wireframe: DelegatedSignValidationWireframeProtocol
    let interactor: DelegatedSignValidationInteractorInputProtocol

    init(
        interactor: DelegatedSignValidationInteractorInputProtocol,
        wireframe: DelegatedSignValidationWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DelegatedSignValidationPresenter: DelegatedSignValidationPresenterProtocol {
    func setup() {}
}

extension DelegatedSignValidationPresenter: DelegatedSignValidationInteractorOutputProtocol {}
