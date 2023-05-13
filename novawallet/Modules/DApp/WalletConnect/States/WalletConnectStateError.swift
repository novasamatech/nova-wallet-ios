import Foundation

enum WalletConnectStateError: Error {
    case unexpectedMessage(Any, WalletConnectStateProtocol)
    case unexpectedData(details: String, WalletConnectStateProtocol)
}

extension WalletConnectStateError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title = R.string.localizable.commonWalletConnect(preferredLanguages: locale?.rLanguages)
        let message: String

        switch self {
        case let .unexpectedData(details, _):
            message = R.string.localizable.dappUnexpectedErrorFormat(
                details,
                preferredLanguages: locale?.rLanguages
            )
        case .unexpectedMessage:
            message = R.string.localizable.dappUnexpectedErrorFormat(
                "unexpected message received",
                preferredLanguages: locale?.rLanguages
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
