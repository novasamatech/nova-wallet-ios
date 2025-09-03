import Foundation

enum DAppInteractionError: Error {
    case unexpected(reason: String, internalError: Error?)
}

extension DAppInteractionError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case let .unexpected(reason, _):
            return .init(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonErrorGeneralTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.dappUnexpectedErrorFormat(
                    reason
                )
            )
        }
    }
}
