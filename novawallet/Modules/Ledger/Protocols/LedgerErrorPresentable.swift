import Foundation

protocol LedgerErrorPresentable: MessageSheetPresentable {
    func presentLedgerError(
        on view: ControllerBackedProtocol,
        error: LedgerError,
        networkName: String,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback
    )
}

extension LedgerErrorPresentable {
    func presentLedgerError(
        on view: ControllerBackedProtocol,
        error: LedgerError,
        networkName: String,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping MessageSheetCallback
    ) {
        switch error {
        case .deviceNotFound, .deviceDisconnected:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createDeviceNotConnectedView(
                cancelClosure: cancelClosure,
                retryClosure: retryClosure
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case let .response(ledgerResponseError):
            presentLedger(
                on: view,
                response: ledgerResponseError,
                networkName: networkName,
                cancelClosure: cancelClosure,
                retryClosure: retryClosure
            )
        case let .unexpectedData(message):
            guard let messageSheetView = LedgerMessageSheetViewFactory.createMessageErrorView(
                message: message,
                cancelClosure: cancelClosure,
                retryClosure: retryClosure
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case .internalTransport:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createUnknownErrorView(
                cancelClosure: cancelClosure,
                retryClosure: retryClosure
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        }
    }

    private func presentLedger(
        on view: ControllerBackedProtocol,
        response: LedgerResponseError,
        networkName: String,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping () -> Void
    ) {
        switch response.code {
        case .noError:
            break
        case .appNotOpen, .wrongAppOpen:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createNetworkAppNotLaunchedView(
                chainName: networkName,
                cancelClosure: cancelClosure,
                retryClosure: retryClosure
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case .transactionRejected:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createOperationCancelledView(
                cancelClosure: cancelClosure,
                retryClosure: retryClosure
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case .invalidData:
            if let reason = response.reason {
                presentInvalidDataReasonError(
                    on: view,
                    reason: LedgerInvaliDataPolkadotReason(rawReason: reason),
                    networkName: networkName,
                    cancelClosure: cancelClosure,
                    retryClosure: retryClosure
                )
            } else {
                presentUnknownLedgerError(on: view, cancelClosure: cancelClosure, retryClosure: retryClosure)
            }
        default:
            if let reason = response.reason {
                presentMessageLedgerError(
                    on: view,
                    message: reason,
                    cancelClosure: cancelClosure,
                    retryClosure: retryClosure
                )
            } else {
                presentUnknownLedgerError(on: view, cancelClosure: cancelClosure, retryClosure: retryClosure)
            }
        }
    }

    private func presentInvalidDataReasonError(
        on view: ControllerBackedProtocol,
        reason: LedgerInvaliDataPolkadotReason,
        networkName: String,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping () -> Void
    ) {
        switch reason {
        case let .unknown(reason):
            presentMessageLedgerError(
                on: view,
                message: reason,
                cancelClosure: cancelClosure,
                retryClosure: retryClosure
            )
        case .unsupportedOperation:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createTransactionNotSupportedView(
                completionClosure: cancelClosure
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        case .outdatedMetadata:
            guard let messageSheetView = LedgerMessageSheetViewFactory.createMetadataOutdatedView(
                chainName: networkName,
                completionClosure: cancelClosure
            ) else {
                return
            }

            transitToMessageSheet(messageSheetView, on: view)
        }
    }

    private func presentMessageLedgerError(
        on view: ControllerBackedProtocol,
        message: String,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping () -> Void
    ) {
        guard let messageSheetView = LedgerMessageSheetViewFactory.createMessageErrorView(
            message: message,
            cancelClosure: cancelClosure,
            retryClosure: retryClosure
        ) else {
            return
        }

        transitToMessageSheet(messageSheetView, on: view)
    }

    private func presentUnknownLedgerError(
        on view: ControllerBackedProtocol,
        cancelClosure: @escaping MessageSheetCallback,
        retryClosure: @escaping () -> Void
    ) {
        guard let messageSheetView = LedgerMessageSheetViewFactory.createUnknownErrorView(
            cancelClosure: cancelClosure,
            retryClosure: retryClosure
        ) else {
            return
        }

        transitToMessageSheet(messageSheetView, on: view)
    }
}
