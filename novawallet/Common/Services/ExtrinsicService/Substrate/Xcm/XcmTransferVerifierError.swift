import Foundation

enum XcmTransferVerifierError: Error {
    case verificationFailed(Error)
}

extension XcmTransferVerifierError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case .verificationFailed:
            ErrorContent(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonDryRunFailedTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonDryRunFailedMessage()
            )
        }
    }
}
