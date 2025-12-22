import Foundation
import SubstrateSdk

extension JSONRPCError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let details: String

        if let data = data {
            title = message
            details = "\(data) (code \(code))"
        } else {
            title = R.string(preferredLanguages: locale.rLanguages).localizable.operationErrorTitle()
            details = "\(message) (code \(code))"
        }

        return ErrorContent(title: title, message: details)
    }
}
