import Foundation

enum WalletConnectStateError: Error {
    case unexpectedMessage(Any, WalletConnectStateProtocol)
    case unexpectedData(details: String, WalletConnectStateProtocol)
}

extension WalletConnectStateError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonWalletConnect()
        let message: String

        switch self {
        case let .unexpectedData(details, _):
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.dappUnexpectedErrorFormat(
                details
            )
        case .unexpectedMessage:
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.dappUnexpectedErrorFormat(
                "unexpected message received"
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
