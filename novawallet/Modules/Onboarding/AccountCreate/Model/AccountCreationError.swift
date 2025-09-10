import Foundation

enum AccountCreationError: Error {
    case unsupportedNetwork
    case invalidDerivationHardSoftNumericPassword
    case invalidDerivationHardSoftPassword
    case invalidDerivationHardPassword
    case invalidDerivationHardSoftNumeric
    case invalidDerivationHardSoft
    case invalidDerivationHard
}

extension AccountCreationError: ErrorContentConvertible {
    private func getTitle(for locale: Locale?) -> String {
        switch self {
        case .unsupportedNetwork:
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        default:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonInvalidPathTitle_v2_2_0()
        }
    }

    private func getMessage(for locale: Locale?) -> String {
        switch self {
        case .unsupportedNetwork:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonUnsupportedNetworkMessage()

        case .invalidDerivationHardSoftNumericPassword,
             .invalidDerivationHardSoftPassword,
             .invalidDerivationHardPassword,
             .invalidDerivationHardSoftNumeric,
             .invalidDerivationHardSoft,
             .invalidDerivationHard:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonInvalidDerivationPathMessage_v2_2_0()
        }
    }

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title = getTitle(for: locale)
        let message = getMessage(for: locale)

        return ErrorContent(title: title, message: message)
    }
}
