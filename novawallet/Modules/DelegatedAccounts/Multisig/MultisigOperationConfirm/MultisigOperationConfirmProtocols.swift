protocol MultisigOperationConfirmViewProtocol: ControllerBackedProtocol {}

protocol MultisigOperationConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func confirm()
}

protocol MultisigOperationConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveOperation(_ operation: Multisig.PendingOperation?)
    func didReceiveSignatories(_ signatories: [Multisig.Signatory])
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didCompleteSubmission()
    func didReceiveError(_ error: MultisigOperationConfirmInteractorError)
}

protocol MultisigOperationConfirmWireframeProtocol: AnyObject {}

enum MultisigOperationConfirmInteractorError {
    case signatoriesFetchFailed(Error)
    case callProcessingFailed(Error)
    case feeError(Error)
    case submissionError(Error)
}
