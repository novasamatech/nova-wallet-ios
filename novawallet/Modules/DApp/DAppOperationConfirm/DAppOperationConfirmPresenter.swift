import Foundation

final class DAppOperationConfirmPresenter {
    weak var view: DAppOperationConfirmViewProtocol?
    let wireframe: DAppOperationConfirmWireframeProtocol
    let interactor: DAppOperationConfirmInteractorInputProtocol

    init(
        interactor: DAppOperationConfirmInteractorInputProtocol,
        wireframe: DAppOperationConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DAppOperationConfirmPresenter: DAppOperationConfirmPresenterProtocol {
    func setup() {}
}

extension DAppOperationConfirmPresenter: DAppOperationConfirmInteractorOutputProtocol {}
