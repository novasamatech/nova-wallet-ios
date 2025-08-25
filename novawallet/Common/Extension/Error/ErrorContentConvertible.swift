import Foundation

struct ErrorContent {
    let title: String
    let message: String
}

protocol ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent
}
