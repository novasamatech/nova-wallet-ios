import UIKit
import UIKit_iOS
import Foundation_iOS

final class LedgerTxConfirmWireframe: LedgerTxConfirmWireframeProtocol {
    func complete(on view: ControllerBackedProtocol?, completionClosure: @escaping () -> Void) {
        view?.controller.dismiss(animated: true, completion: completionClosure)
    }

    func transitToTransactionReview(
        on view: ControllerBackedProtocol?,
        timer: CountdownTimerMediator,
        deviceInfo: LedgerDeviceDisplayInfo,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel?,
        cancelClosure: @escaping () -> Void
    ) {
        guard let view = view else {
            return
        }

        guard
            let transactionSignView = LedgerMessageSheetViewFactory.createReviewLedgerTransactionView(
                for: timer,
                deviceName: deviceInfo.deviceName,
                deviceModel: deviceInfo.deviceModel,
                cancelClosure: cancelClosure,
                migrationViewModel: migrationViewModel
            ) else {
            return
        }

        transitToMessageSheet(transactionSignView, on: view)
    }

    func transitToTransactionExpired(
        on view: ControllerBackedProtocol?,
        expirationTimeInterval: TimeInterval,
        deviceModel: LedgerDeviceModel,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel?,
        completion: @escaping MessageSheetCallback
    ) {
        guard let view = view else {
            return
        }

        guard
            let transactionExpiredView = LedgerMessageSheetViewFactory.createTransactionExpiredView(
                for: expirationTimeInterval,
                deviceModel: deviceModel,
                completionClosure: completion,
                migrationViewModel: migrationViewModel
            ) else {
            return
        }

        transitToMessageSheet(transactionExpiredView, on: view)
    }

    func transitToInvalidSignature(
        on view: ControllerBackedProtocol?,
        deviceModel: LedgerDeviceModel,
        migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel?,
        completion: @escaping MessageSheetCallback
    ) {
        guard let view = view else {
            return
        }

        guard let invalidSignatureView = LedgerMessageSheetViewFactory.createSignatureInvalidView(
            deviceModel: deviceModel,
            completionClosure: completion,
            migrationViewModel: migrationViewModel
        ) else {
            return
        }

        transitToMessageSheet(invalidSignatureView, on: view)
    }
}
