import Foundation

struct LedgerErrorPresentableCallbacks {
    let cancelClosure: MessageSheetCallback
    let retryClosure: MessageSheetCallback

    init(
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback
    ) {
        self.cancelClosure = cancelClosure
        self.retryClosure = retryClosure
    }
}

struct LedgerErrorPresentableContext {
    let networkName: String
    let deviceModel: LedgerDeviceModel
    let migrationViewModel: MessageSheetMigrationBannerView.ContentViewModel?
}

protocol LedgerErrorPresentable: MessageSheetPresentable {
    func presentLedgerError(
        on view: ControllerBackedProtocol,
        error: LedgerError,
        context: LedgerErrorPresentableContext,
        callbacks: LedgerErrorPresentableCallbacks
    )
}

extension LedgerErrorPresentable {
    func presentLedgerError(
        on view: ControllerBackedProtocol,
        error: LedgerError,
        context: LedgerErrorPresentableContext,
        callbacks: LedgerErrorPresentableCallbacks
    ) {
        switch error {
        case .deviceNotFound, .deviceDisconnected:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createDeviceNotConnectedView(
                cancelClosure: callbacks.cancelClosure,
                retryClosure: callbacks.retryClosure,
                migrationViewModel: context.migrationViewModel
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case let .response(ledgerResponseError):
            presentLedger(
                on: view,
                response: ledgerResponseError,
                context: context,
                callbacks: callbacks
            )
        case let .unexpectedData(message):
            guard let messageSheetView = LedgerMessageSheetViewFactory.createMessageErrorView(
                message: message,
                deviceModel: context.deviceModel,
                cancelClosure: callbacks.cancelClosure,
                retryClosure: callbacks.retryClosure,
                migrationViewModel: context.migrationViewModel
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case .internalTransport:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createUnknownErrorView(
                cancelClosure: callbacks.cancelClosure,
                retryClosure: callbacks.retryClosure,
                migrationViewModel: context.migrationViewModel
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        }
    }

    private func presentLedger(
        on view: ControllerBackedProtocol,
        response: LedgerResponseError,
        context: LedgerErrorPresentableContext,
        callbacks: LedgerErrorPresentableCallbacks
    ) {
        switch response.code {
        case .noError:
            break
        case .appNotOpen, .wrongAppOpen:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createNetworkAppNotLaunchedView(
                chainName: context.networkName,
                deviceModel: context.deviceModel,
                cancelClosure: callbacks.cancelClosure,
                retryClosure: callbacks.retryClosure,
                migrationViewModel: context.migrationViewModel
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case .transactionRejected:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createOperationCancelledView(
                deviceModel: context.deviceModel,
                cancelClosure: callbacks.cancelClosure,
                retryClosure: callbacks.retryClosure,
                migrationViewModel: context.migrationViewModel
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case .invalidData:
            if let reason = response.reason {
                presentInvalidDataReasonError(
                    on: view,
                    reason: LedgerInvaliDataPolkadotReason(rawReason: reason),
                    context: context,
                    callbacks: callbacks
                )
            } else {
                presentUnknownLedgerError(
                    on: view,
                    context: context,
                    callbacks: callbacks
                )
            }
        default:
            if let reason = response.reason {
                presentMessageLedgerError(
                    on: view,
                    message: reason,
                    context: context,
                    callbacks: callbacks
                )
            } else {
                presentUnknownLedgerError(
                    on: view,
                    context: context,
                    callbacks: callbacks
                )
            }
        }
    }

    private func presentInvalidDataReasonError(
        on view: ControllerBackedProtocol,
        reason: LedgerInvaliDataPolkadotReason,
        context: LedgerErrorPresentableContext,
        callbacks: LedgerErrorPresentableCallbacks
    ) {
        switch reason {
        case let .unknown(reason):
            presentMessageLedgerError(
                on: view,
                message: reason,
                context: context,
                callbacks: callbacks
            )
        case .unsupportedOperation:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createTransactionNotSupportedView(
                deviceModel: context.deviceModel,
                completionClosure: callbacks.cancelClosure,
                migrationViewModel: context.migrationViewModel
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case .outdatedMetadata:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createMetadataOutdatedView(
                chainName: context.networkName,
                deviceModel: context.deviceModel,
                completionClosure: callbacks.cancelClosure,
                migrationViewModel: context.migrationViewModel
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        }
    }

    private func presentMessageLedgerError(
        on view: ControllerBackedProtocol,
        message: String,
        context: LedgerErrorPresentableContext,
        callbacks: LedgerErrorPresentableCallbacks
    ) {
        guard let messageSheetView = LedgerMessageSheetViewFactory.createMessageErrorView(
            message: message,
            deviceModel: context.deviceModel,
            cancelClosure: callbacks.cancelClosure,
            retryClosure: callbacks.retryClosure,
            migrationViewModel: context.migrationViewModel
        ) else {
            return
        }

        transitToMessageSheet(messageSheetView, on: view)
    }

    private func presentUnknownLedgerError(
        on view: ControllerBackedProtocol,
        context: LedgerErrorPresentableContext,
        callbacks: LedgerErrorPresentableCallbacks
    ) {
        guard let messageSheetView = LedgerMessageSheetViewFactory.createUnknownErrorView(
            cancelClosure: callbacks.cancelClosure,
            retryClosure: callbacks.retryClosure,
            migrationViewModel: context.migrationViewModel
        ) else {
            return
        }

        transitToMessageSheet(messageSheetView, on: view)
    }
}
