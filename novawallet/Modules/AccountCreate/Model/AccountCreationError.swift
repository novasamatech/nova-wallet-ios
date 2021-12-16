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
            return R.string.localizable
                .commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        default:
            return R.string.localizable
                .commonInvalidPathTitle_v2_2_0(preferredLanguages: locale?.rLanguages)
        }
    }

    private func getMessage(for locale: Locale?) -> String {
        switch self {
        case .unsupportedNetwork:
            return R.string.localizable
                .commonUnsupportedNetworkMessage(preferredLanguages: locale?.rLanguages)

        case .invalidDerivationHardSoftNumericPassword,
             .invalidDerivationHardSoftPassword,
             .invalidDerivationHardPassword,
             .invalidDerivationHardSoftNumeric,
             .invalidDerivationHardSoft,
             .invalidDerivationHard:
            return R.string.localizable
                .commonInvalidDerivationPathMessage_v2_2_0(preferredLanguages: locale?.rLanguages)
        }
    }

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title = getTitle(for: locale)
        let message = getMessage(for: locale)

        return ErrorContent(title: title, message: message)
    }
}
