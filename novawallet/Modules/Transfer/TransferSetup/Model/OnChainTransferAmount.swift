import Foundation

enum OnChainTransferAmount<T> {
    case concrete(value: T)
    case all(value: T)

    var value: T {
        switch self {
        case let .concrete(value):
            return value
        case let .all(value):
            return value
        }
    }

    var name: String {
        switch self {
        case .concrete:
            return "concrete"
        case .all:
            return "all"
        }
    }

    func flatMap<V>(_ closure: (T) -> V?) -> OnChainTransferAmount<V>? {
        guard let newValue = closure(value) else {
            return nil
        }

        switch self {
        case .concrete:
            return .concrete(value: newValue)
        case .all:
            return .all(value: newValue)
        }
    }

    func map<V>(_ closure: (T) -> V) -> OnChainTransferAmount<V> {
        switch self {
        case let .concrete(value):
            return .concrete(value: closure(value))
        case let .all(value):
            return .all(value: closure(value))
        }
    }
}
