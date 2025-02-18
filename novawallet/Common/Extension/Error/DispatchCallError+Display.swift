import Foundation

extension DispatchCallError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title = R.string.localizable.operationErrorTitle(preferredLanguages: locale?.rLanguages)
        let details: String

        switch self {
        case let .module(moduleError):
            details = "\(moduleError.display.moduleName):\(moduleError.display.errorName)"
        case let .other(message):
            details = "Other: \(message)"
        }

        return ErrorContent(title: title, message: details)
    }
}
