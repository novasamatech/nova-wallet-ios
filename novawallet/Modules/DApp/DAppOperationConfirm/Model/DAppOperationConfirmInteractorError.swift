import Foundation

enum DAppOperationConfirmInteractorError: Error {
    case addressMismatch(actual: AccountAddress, expected: AccountAddress)
    case extrinsicBadField(name: String)
    case signedExtensionsMismatch(actual: [String], expected: [String])
    case invalidRawSignature(data: Data)
    case signingFailed
}

extension DAppOperationConfirmInteractorError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String = R.string.localizable.commonErrorGeneralTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message: String

        switch self {
        case let .addressMismatch(actual, expected):
            message = R.string.localizable.dappConfirmationAddressMismatch(
                actual,
                expected,
                preferredLanguages: locale?.rLanguages
            )
        case let .extrinsicBadField(name):
            message = R.string.localizable.dappConfirmationBadField(
                name,
                preferredLanguages: locale?.rLanguages
            )
        case .signedExtensionsMismatch:
            message = R.string.localizable.dappConfirmationExtensionsMismatch(
                preferredLanguages: locale?.rLanguages
            )
        case .invalidRawSignature:
            message = R.string.localizable.dappConfirmationInvalidSignature(
                preferredLanguages: locale?.rLanguages
            )
        case .signingFailed:
            message = R.string.localizable.dappSignExtrinsicFailed(preferredLanguages: locale?.rLanguages)
        }

        return ErrorContent(title: title, message: message)
    }
}
