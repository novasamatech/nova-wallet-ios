import Foundation

protocol LedgerErrorPresentable {
    func presentLedgerError(
        on view: ControllerBackedProtocol,
        error: LedgerError,
        networkName: String,
        locale: Locale,
        retryClosure: @escaping () -> Void
    )
}

extension LedgerErrorPresentable where Self: AlertPresentable & CommonRetryable {
    func presentLedgerError(
        on view: ControllerBackedProtocol,
        error: LedgerError,
        networkName: String,
        locale: Locale,
        retryClosure: @escaping () -> Void
    ) {
        switch error {
        case .deviceNotFound, .deviceDisconnected:
            presentRequestStatus(
                on: view,
                title: R.string.localizable.ledgerOperationTitle(preferredLanguages: locale.rLanguages),
                message: R.string.localizable.ledgerOperationDeviceNotConnected(preferredLanguages: locale.rLanguages),
                cancelAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages),
                locale: locale,
                retryAction: retryClosure
            )
        case let .response(ledgerResponseError):
            presentLedger(
                on: view,
                response: ledgerResponseError.code,
                networkName: networkName,
                locale: locale,
                retryClosure: retryClosure
            )
        case let .unexpectedData(message):
            present(
                message: message,
                title: R.string.localizable.ledgerOperationTitle(preferredLanguages: locale.rLanguages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
                from: view
            )
        case .internalTransport:
            present(
                message: R.string.localizable.ledgerOperationMessageError(preferredLanguages: locale.rLanguages),
                title: R.string.localizable.ledgerOperationTitle(preferredLanguages: locale.rLanguages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
                from: view
            )
        }
    }

    private func presentLedger(
        on view: ControllerBackedProtocol,
        response: LedgerResponseCode,
        networkName: String,
        locale: Locale,
        retryClosure: @escaping () -> Void
    ) {
        switch response {
        case .noError:
            break
        case .appNotOpen, .wrongAppOpen:
            presentRequestStatus(
                on: view,
                title: R.string.localizable.ledgerAppNotOpenTitle(networkName, preferredLanguages: locale.rLanguages),
                message: R.string.localizable.ledgerAppNotOpenMessage(
                    networkName,
                    preferredLanguages: locale.rLanguages
                ),
                cancelAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages),
                locale: locale,
                retryAction: retryClosure
            )
        case .deviceBusy:
            presentRequestStatus(
                on: view,
                title: R.string.localizable.ledgerDeviceBusyTitle(preferredLanguages: locale.rLanguages),
                message: R.string.localizable.ledgerDeviceBusyMessage(preferredLanguages: locale.rLanguages),
                cancelAction: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages),
                locale: locale,
                retryAction: retryClosure
            )
        case .transactionRejected:
            present(
                message: R.string.localizable.ledgerOperationMessageCancelled(preferredLanguages: locale.rLanguages),
                title: R.string.localizable.ledgerOperationTitle(preferredLanguages: locale.rLanguages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
                from: view
            )
        default:
            present(
                message: R.string.localizable.ledgerOperationMessageError(preferredLanguages: locale.rLanguages),
                title: R.string.localizable.ledgerOperationTitle(preferredLanguages: locale.rLanguages),
                closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
                from: view
            )
        }
    }
}
