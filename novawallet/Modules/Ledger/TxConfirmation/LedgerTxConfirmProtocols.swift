import IrohaCrypto

protocol LedgerTxConfirmPresenterProtocol: LedgerPerformOperationPresenterProtocol {
    func cancel()
}

protocol LedgerTxConfirmInteractorOutputProtocol: LedgerPerformOperationOutputProtocol {
    func didReceiveSigning(result: Result<IRSignatureProtocol, Error>, for deviceId: UUID)
}

protocol LedgerTxConfirmWireframeProtocol: LedgerPerformOperationWireframeProtocol {
    func complete(on view: ControllerBackedProtocol?)
}
