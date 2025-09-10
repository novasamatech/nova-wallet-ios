import Foundation

protocol WalletConnectErrorPresentable {
    func presentWCConnectionError(from view: ControllerBackedProtocol?, error: Error, locale: Locale?)
    func presentWCDisconnectionError(from view: ControllerBackedProtocol?, error: Error, locale: Locale?)
    func presentWCSignatureSubmissionError(from view: ControllerBackedProtocol?, locale: Locale?)
    func presentWCAuthSubmissionError(from view: ControllerBackedProtocol?, locale: Locale?)
}

extension WalletConnectErrorPresentable where Self: AlertPresentable {
    private func presentWCError(from view: ControllerBackedProtocol?, message: String, locale: Locale?) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonWalletConnect()

        present(
            message: message,
            title: title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            from: view
        )
    }

    func presentWCConnectionError(from view: ControllerBackedProtocol?, error: Error, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.walletConnectPairingError()

        presentWCError(from: view, message: message + " " + "(\(error))", locale: locale)
    }

    func presentWCDisconnectionError(from view: ControllerBackedProtocol?, error: Error, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.walletConnectDisconnectError()

        presentWCError(from: view, message: message + " " + "(\(error))", locale: locale)
    }

    func presentWCSignatureSubmissionError(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.walletConnectSignatureSubmitError()

        presentWCError(from: view, message: message, locale: locale)
    }

    func presentWCAuthSubmissionError(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.walletConnectProposalResultSubmitError()

        presentWCError(from: view, message: message, locale: locale)
    }
}
