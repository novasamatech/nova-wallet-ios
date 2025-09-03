import Foundation

enum AccountCreateError: Error {
    case invalidMnemonicSize
    case invalidMnemonicFormat
    case invalidSeed
    case invalidKeystore
    case unsupportedNetwork
    case duplicated
}

extension AccountCreateError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let message: String

        switch self {
        case .invalidMnemonicSize:
            message = R.string(preferredLanguages: locale.rLanguages).localizable
                .accessRestoreWordsErrorMessage()
        case .invalidMnemonicFormat:
            message = R.string(preferredLanguages: locale.rLanguages).localizable
                .accessRestorePhraseErrorMessage_v2_2_0()
        case .invalidSeed:
            message = R.string(preferredLanguages: locale.rLanguages).localizable
                .accountImportInvalidSeed()
        case .invalidKeystore:
            message = R.string(preferredLanguages: locale.rLanguages).localizable
                .accountImportInvalidKeystore()
        case .unsupportedNetwork:
            message = R.string(preferredLanguages: locale.rLanguages).localizable
                .commonUnsupportedNetworkMessage()
        case .duplicated:
            message = R.string(preferredLanguages: locale.rLanguages).localizable
                .accountAddAlreadyExistsMessage()
        }

        return ErrorContent(title: title, message: message)
    }
}
