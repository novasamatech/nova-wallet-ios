import IrohaCrypto
import Foundation

protocol LedgerTxConfirmPresenterProtocol: LedgerPerformOperationPresenterProtocol {
    func cancel()
}

protocol LedgerTxConfirmInteractorInputProtocol: LedgerPerformOperationInputProtocol {
    func cancelTransactionRequest(for deviceId: UUID)
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
        deviceName: String,
        cancelClosure: @escaping () -> Void
    )

    func transitToTransactionExpired(
        on view: ControllerBackedProtocol?,
        expirationTimeInterval: TimeInterval,
        completion: @escaping MessageSheetCallback
    )

    func transitToTransactionNotSupported(
        on view: ControllerBackedProtocol?,
        completion: @escaping MessageSheetCallback
    )

    func transitToMetadataOutdated(
        on view: ControllerBackedProtocol?,
        chainName: String,
        completion: @escaping MessageSheetCallback
    )

    func transitToInvalidSignature(
        on view: ControllerBackedProtocol?,
        completion: @escaping MessageSheetCallback
    )

    func transitToInvalidData(
        on view: ControllerBackedProtocol?,
        reason: String,
        completion: @escaping MessageSheetCallback
    )

    func closeTransactionStatus(on view: ControllerBackedProtocol?)
}
