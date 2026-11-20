import Foundation

enum DAppOperationConfirmInteractorError: Error {
    case addressMismatch(actual: AccountAddress, expected: AccountAddress)
    case extrinsicBadField(name: String)
    case invalidRawSignature(data: Data)
    case signingFailed

    /**
     *   There is nothing to sign: the request is still being prepared (no reason) or the preparation
     *   has failed on the wallet's side, for example the node couldn't be reached
     */
    case requestNotPrepared(reason: Error?)
}

extension DAppOperationConfirmInteractorError {
    /**
     *  The failures of a signer the confirmation presents in their own way are kept,
     *  anything else is reported as a failed signing.
     */
    static func signingError(from error: Error) -> Error {
        if let noKeysError = error as? NoKeysSigningWrapperError {
            return noKeysError
        } else if let hardwareSigningError = error as? HardwareSigningError {
            return hardwareSigningError
        } else if let operationError = error as? DAppOperationConfirmInteractorError {
            return operationError
        } else {
            return DAppOperationConfirmInteractorError.signingFailed
        }
    }
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
        case .requestNotPrepared:
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.operationErrorMessage()
        }

        return ErrorContent(title: title, message: message)
    }
}
