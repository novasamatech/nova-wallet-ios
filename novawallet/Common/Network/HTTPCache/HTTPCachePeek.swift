import Foundation

enum HTTPCachePeek<Value> {
    case fresh(Value, freshUntil: TimeInterval)
    case expired(Value)
    case miss
}

extension HTTPCachePeek {
    var value: Value? {
        switch self {
        case let .fresh(value, _), let .expired(value):
            return value
        case .miss:
            return nil
        }
    }

    var isFresh: Bool {
        switch self {
        case .fresh:
            return true
        case .expired, .miss:
            return false
        }
    }

    func map<T>(_ transform: (Value) throws -> T) -> HTTPCachePeek<T> {
        do {
            switch self {
            case let .fresh(value, freshUntil):
                return .fresh(try transform(value), freshUntil: freshUntil)
            case let .expired(value):
                return .expired(try transform(value))
            case .miss:
                return .miss
            }
        } catch {
            return .miss
        }
    }
}
