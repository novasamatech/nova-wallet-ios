import Foundation

extension AccountOperationFactoryError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .decryption:
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.accountImportKeystoreDecryptionErrorTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.accountImportKeystoreDecryptionErrorMessage()
        default:
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonErrorGeneralTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonUndefinedErrorMessage()
        }

        return ErrorContent(title: title, message: message)
    }
}
