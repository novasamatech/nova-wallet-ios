import Foundation

enum UncertainStorage<T> {
    case undefined
    case defined(T)

    var isDefined: Bool {
        switch self {
        case .defined:
            return true
        case .undefined:
            return false
        }
    }

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

    func valueWhenDefined(else defaultValue: T) -> T {
        switch self {
        case let .defined(value):
            return value
        case .undefined:
            return defaultValue
        }
    }

    func valueWhenDefinedElseThrow(_ message: String) throws -> T {
        switch self {
        case let .defined(value):
            return value
        case .undefined:
            throw UncertainStorageError.undefined(message)
        }
    }
}

enum UncertainStorageError: Error {
    case undefined(String)
}

extension UncertainStorage where T: Decodable {
    init(
        values: [BatchStorageSubscriptionResultValue],
        mappingKey: String,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        if let wrappedValue = values.first(where: { $0.mappingKey == mappingKey }) {
            let value = try wrappedValue.value.map(to: T.self, with: context)
            self = .defined(value)
        } else {
            self = .undefined
        }
    }
}

extension UncertainStorage: Equatable where T: Equatable {}
