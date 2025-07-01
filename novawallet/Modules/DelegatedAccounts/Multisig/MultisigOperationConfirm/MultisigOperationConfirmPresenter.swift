import Foundation

final class MultisigOperationConfirmPresenter {
    weak var view: MultisigOperationConfirmViewProtocol?
    let wireframe: MultisigOperationConfirmWireframeProtocol
    let interactor: MultisigOperationConfirmInteractorInputProtocol

    let logger: LoggerProtocol

    init(
        interactor: MultisigOperationConfirmInteractorInputProtocol,
        wireframe: MultisigOperationConfirmWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }
}

extension MultisigOperationConfirmPresenter: MultisigOperationConfirmPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension MultisigOperationConfirmPresenter: MultisigOperationConfirmInteractorOutputProtocol {
    func didReceiveOperation(_ operation: Multisig.PendingOperation?) {
        logger.debug("Operation \(String(describing: operation))")
    }

    func didReceiveSignatories(_ signatories: [Multisig.Signatory]) {
        logger.debug("Signatories: \(signatories)")
    }

    func didReceiveError(_ error: MultisigOperationConfirmInteractorError) {
        logger.error("Error: \(error)")
    }
}
