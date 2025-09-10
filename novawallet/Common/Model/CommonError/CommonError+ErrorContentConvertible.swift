import Foundation

extension CommonError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case .undefined:
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonUndefinedErrorTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonUndefinedErrorMessage()
        case .dataCorruption:
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonErrorGeneralTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonDataCorruptionError()
        case .databaseSubscription:
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonErrorGeneralTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonDbSubscriptionError()
        case .noDataRetrieved:
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonErrorGeneralTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonErrorNoDataRetrieved()
        }

        return ErrorContent(title: title, message: message)
    }
}
