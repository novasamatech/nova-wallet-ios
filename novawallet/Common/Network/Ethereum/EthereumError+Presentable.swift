import Foundation

extension EthereumRpcError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title = R.string.localizable.operationErrorTitle(preferredLanguages: locale?.rLanguages)
        let details = "\(message) (code \(code))"

        return ErrorContent(title: title, message: details)
    }
}
