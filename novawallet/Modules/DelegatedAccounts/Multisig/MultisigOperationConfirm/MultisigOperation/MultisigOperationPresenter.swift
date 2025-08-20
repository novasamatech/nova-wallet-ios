import Foundation

final class MultisigOperationPresenter {
    weak var view: MultisigOperationViewProtocol?

    let wireframe: MultisigOperationWireframeProtocol
    let interactor: MultisigOperationInteractorInputProtocol

    init(
        wireframe: MultisigOperationWireframeProtocol,
        interactor: MultisigOperationInteractorInputProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
    }
}

// MARK: - MultisigOperationPresenterProtocol

extension MultisigOperationPresenter: MultisigOperationPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

// MARK: - MultisigOperationInteractorOutputProtocol

extension MultisigOperationPresenter: MultisigOperationInteractorOutputProtocol {
    func didReceiveOperation(_ operation: Multisig.PendingOperationProxyModel?) {
        guard let operation else {
            view?.didReceive(loading: true)
            return
        }

        view?.didReceive(loading: false)

        wireframe.showConfirmationData(
            from: view,
            for: operation
        )
    }
}
