import Foundation

enum DAppBrowserStateError: Error {
    case unexpected(reason: String)
}

extension DAppBrowserStateError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case let .unexpected(reason):
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonErrorGeneralTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.dappUnexpectedErrorFormat(
                reason
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
