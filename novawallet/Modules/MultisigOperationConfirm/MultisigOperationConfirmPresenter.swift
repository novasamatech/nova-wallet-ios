import Foundation

final class MultisigOperationConfirmPresenter {
    weak var view: MultisigOperationConfirmViewProtocol?
    let wireframe: MultisigOperationConfirmWireframeProtocol
    let interactor: MultisigOperationConfirmInteractorInputProtocol

    init(
        interactor: MultisigOperationConfirmInteractorInputProtocol,
        wireframe: MultisigOperationConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension MultisigOperationConfirmPresenter: MultisigOperationConfirmPresenterProtocol {
    func setup() {}
}

extension MultisigOperationConfirmPresenter: MultisigOperationConfirmInteractorOutputProtocol {}
