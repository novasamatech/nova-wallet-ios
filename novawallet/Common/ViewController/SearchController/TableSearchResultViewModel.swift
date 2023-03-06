import Foundation

enum TableSearchResultViewModel<T> {
    case start
    case notFound
    case found(title: TitleWithSubtitleViewModel, items: [T])

    var items: [T]? {
        switch self {
        case .start, .notFound:
            return nil
        case let .found(_, items):
            return items
        }
    }

    var title: TitleWithSubtitleViewModel? {
        switch self {
        case .start, .notFound:
            return nil
        case let .found(title, _):
            return title
        }
    }
}
