import IrohaCrypto

protocol LedgerTxConfirmPresenterProtocol: LedgerPerformOperationPresenterProtocol {
    func cancel()
}

protocol LedgerTxConfirmInteractorOutputProtocol: LedgerPerformOperationOutputProtocol {
    func didReceiveSigning(result: Result<IRSignatureProtocol, Error>, for deviceId: UUID)
    func didReceiveTransactionExpiration(timeInterval: TimeInterval)
}

protocol LedgerTxConfirmWireframeProtocol: LedgerPerformOperationWireframeProtocol {
    func complete(on view: ControllerBackedProtocol?)

    func transitToTransactionReview(
        on view: ControllerBackedProtocol?,
        timer: CountdownTimerMediator,
        deviceName: String
    )

    func transitToTransactionExpired(
        on view: ControllerBackedProtocol?,
        expirationTimeInterval: TimeInterval,
        completion: @escaping MessageSheetCallback
    )

    func closeTransactionStatus(on view: ControllerBackedProtocol?)
}
