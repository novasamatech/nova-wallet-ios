import Foundation

extension DispatchCallError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.operationErrorTitle()
        let details: String

        switch self {
        case let .module(moduleError):
            details = "\(moduleError.display.moduleName): \(moduleError.display.errorName)"
        case let .other(otherError):
            details = "\(otherError.module): \(otherError.reason ?? "Unknown reason")"
        }

        return ErrorContent(title: title, message: details)
    }
}
