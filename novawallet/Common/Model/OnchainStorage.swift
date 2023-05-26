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

    func map<V>(_ closure: (T) -> V) -> UncertainStorage<V> {
        switch self {
        case let .defined(value):
            let newValue = closure(value)
            return .defined(newValue)
        case .undefined:
            return .undefined
        }
    }
}

extension UncertainStorage where T: Decodable {
    init(
        values: [BatchStorageSubscriptionResultValue],
        localKey: String,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        if let wrappedValue = values.first(where: { $0.localKey == localKey }) {
            let value = try wrappedValue.value.map(to: T.self, with: context)
            self = .defined(value)
        } else {
            self = .undefined
        }
    }
}
