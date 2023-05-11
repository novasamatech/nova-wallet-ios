import Foundation

enum DAppInteractionError: Error {
    case unexpected(reason: String, internalError: Error?)
}

extension DAppInteractionError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case let .unexpected(reason, _):
            title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
            message = R.string.localizable.dappUnexpectedErrorFormat(
                reason,
                preferredLanguages: locale?.rLanguages
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
