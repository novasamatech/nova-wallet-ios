import NovaCrypto
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

protocol LedgerTxConfirmWireframeProtocol: LedgerPerformOperationWireframeProtocol, WebPresentable {
    func complete(on view: ControllerBackedProtocol?, completionClosure: @escaping () -> Void)

    func transitToTransactionReview(
        on view: ControllerBackedProtocol?,
        timer: CountdownTimerMediator,
        deviceInfo: LedgerDeviceDisplayInfo,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel?,
        cancelClosure: @escaping () -> Void
    )

    func transitToTransactionExpired(
        on view: ControllerBackedProtocol?,
        expirationTimeInterval: TimeInterval,
        deviceModel: LedgerDeviceModel,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel?,
        completion: @escaping MessageSheetCallback
    )

    func transitToInvalidSignature(
        on view: ControllerBackedProtocol?,
        deviceModel: LedgerDeviceModel,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel?,
        completion: @escaping MessageSheetCallback
    )
}

enum LedgerTxConfirmInteractorError: Error {
    case invalidSignature
}
