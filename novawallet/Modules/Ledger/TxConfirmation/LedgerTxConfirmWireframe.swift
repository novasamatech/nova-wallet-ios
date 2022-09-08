import UIKit
import SoraUI
import SoraFoundation

final class LedgerTxConfirmWireframe: LedgerTxConfirmWireframeProtocol {
    func complete(on view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func transitToTransactionReview(
        on view: ControllerBackedProtocol?,
        timer: CountdownTimerMediator,
        deviceName: String,
        cancelClosure: @escaping () -> Void
    ) {
        guard let view = view else {
            return
        }

        guard
            let transactionSignView = LedgerMessageSheetViewFactory.createReviewLedgerTransactionView(
                for: timer,
                deviceName: deviceName,
                cancelClosure: cancelClosure
            ) else {
            return
        }

        transitToMessageSheet(transactionSignView, on: view)
    }

    func transitToTransactionExpired(
        on view: ControllerBackedProtocol?,
        expirationTimeInterval: TimeInterval,
        completion: @escaping MessageSheetCallback
    ) {
        guard let view = view else {
            return
        }

        guard
            let transactionExpiredView = LedgerMessageSheetViewFactory.createTransactionExpiredView(
                for: expirationTimeInterval,
                completionClosure: completion
            ) else {
            return
        }

        transitToMessageSheet(transactionExpiredView, on: view)
    }

    func transitToInvalidSignature(
        on view: ControllerBackedProtocol?,
        completion: @escaping MessageSheetCallback
    ) {
        guard let view = view else {
            return
        }

        guard let invalidSignatureView = LedgerMessageSheetViewFactory.createSignatureInvalidView(
            completionClosure: completion
        ) else {
            return
        }

        transitToMessageSheet(invalidSignatureView, on: view)
    }
}
