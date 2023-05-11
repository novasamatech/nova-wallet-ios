import Foundation

protocol WalletConnectErrorPresentable {
    func presentWCConnectionError(from view: ControllerBackedProtocol?, locale: Locale?)
    func presentWCDisconnectionError(from view: ControllerBackedProtocol?, locale: Locale?)
    func presentWCSignatureSubmissionError(from view: ControllerBackedProtocol?, locale: Locale?)
    func presentWCAuthSubmissionError(from view: ControllerBackedProtocol?, locale: Locale?)
}

extension WalletConnectErrorPresentable where Self: AlertPresentable {
    private func presentWCError(from view: ControllerBackedProtocol?, message: String, locale: Locale?) {
        let title = R.string.localizable.commonWalletConnect(
            preferredLanguages: locale?.rLanguages
        )

        present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages),
            from: view
        )
    }

    func presentWCConnectionError(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string.localizable.walletConnectPairingError(preferredLanguages: locale?.rLanguages)

        presentWCError(from: view, message: message, locale: locale)
    }

    func presentWCDisconnectionError(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string.localizable.walletConnectDisconnectError(preferredLanguages: locale?.rLanguages)

        presentWCError(from: view, message: message, locale: locale)
    }

    func presentWCSignatureSubmissionError(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string.localizable.walletConnectSignatureSubmitError(
            preferredLanguages: locale?.rLanguages
        )

        presentWCError(from: view, message: message, locale: locale)
    }

    func presentWCAuthSubmissionError(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string.localizable.walletConnectProposalResultSubmitError(
            preferredLanguages: locale?.rLanguages
        )

        presentWCError(from: view, message: message, locale: locale)
    }
}
