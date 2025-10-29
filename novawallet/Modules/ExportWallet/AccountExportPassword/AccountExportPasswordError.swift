import Foundation

enum AccountExportPasswordError: Error {
    case passwordMismatch
}

extension AccountExportPasswordError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let message: String

        switch self {
        case .passwordMismatch:
            message = R.string(preferredLanguages: locale.rLanguages)
                .localizable.commonErrorPasswordMismatch()
        }

        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        return ErrorContent(title: title, message: message)
    }
}
