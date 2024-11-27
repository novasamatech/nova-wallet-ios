import Foundation

enum DAppBrowserWidgetViewModel: Equatable {
    case empty
    case some(title: String)

    var title: String? {
        switch self {
        case .empty:
            nil
        case let .some(title):
            title
        }
    }
}
