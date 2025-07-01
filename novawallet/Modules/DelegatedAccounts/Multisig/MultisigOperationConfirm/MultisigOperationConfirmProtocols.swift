protocol MultisigOperationConfirmViewProtocol: ControllerBackedProtocol {}

protocol MultisigOperationConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationConfirmInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveOperation(_ operation: Multisig.PendingOperation?)
    func didReceiveSignatories(_ signatories: [Multisig.Signatory])
    func didReceiveError(_ error: MultisigOperationConfirmInteractorError)
}

protocol MultisigOperationConfirmWireframeProtocol: AnyObject {}

enum MultisigOperationConfirmInteractorError {
    case signatoriesFetchFailed(Error)
}
