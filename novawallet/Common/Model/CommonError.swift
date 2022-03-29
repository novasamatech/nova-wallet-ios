import Foundation

enum CommonError: Error {
    case undefined
    case databaseSubscription
    case dataCorruption
}

extension CommonError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .undefined:
            title = R.string.localizable
                .commonUndefinedErrorTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable
                .commonUndefinedErrorMessage(preferredLanguages: locale?.rLanguages)
        case .dataCorruption:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.commonDataCorruptionError(
                preferredLanguages: locale?.rLanguages
            )
        case .databaseSubscription:
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.commonDbSubscriptionError(
                preferredLanguages: locale?.rLanguages
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
