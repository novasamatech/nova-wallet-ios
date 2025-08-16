import Foundation

enum XcmTransferVerifierError: Error {
    case verificationFailed(Error)
}

extension XcmTransferVerifierError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case .verificationFailed:
            ErrorContent(
                title: R.string.localizable.commonDryRunFailedTitle(
                    preferredLanguages: locale?.rLanguages
                ),
                message: R.string.localizable.commonDryRunFailedMessage(
                    preferredLanguages: locale?.rLanguages
                )
            )
        }
    }
}
