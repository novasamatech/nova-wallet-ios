import Foundation

enum UncertainStorage<T> {
    case undefined
    case defined(T)

    var value: T? {
        switch self {
        case let .defined(value):
            return value
        case .undefined:
            return nil
        }
    }
}
