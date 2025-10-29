import Foundation

enum DAppOperationConfirmInteractorError: Error {
    case addressMismatch(actual: AccountAddress, expected: AccountAddress)
    case extrinsicBadField(name: String)
    case invalidRawSignature(data: Data)
    case signingFailed
}

extension DAppOperationConfirmInteractorError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonErrorGeneralTitle()

        let message: String

        switch self {
        case let .addressMismatch(actual, expected):
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.dappConfirmationAddressMismatch(
                actual,
                expected
            )
        case let .extrinsicBadField(name):
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.dappConfirmationBadField(
                name
            )
        case .invalidRawSignature:
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.dappConfirmationInvalidSignature()
        case .signingFailed:
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.dappSignExtrinsicFailed()
        }

        return ErrorContent(title: title, message: message)
    }
}
