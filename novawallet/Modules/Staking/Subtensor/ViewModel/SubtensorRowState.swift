import Foundation

enum SubtensorRowState<Value> {
    case hidden
    case loading
    case value(Value)
}

extension SubtensorRowState: Equatable where Value: Equatable {}

extension SubtensorRowState where Value == String {
    static func trade(_ value: String?, isPending: Bool, locale: Locale) -> SubtensorRowState<String> {
        if let value {
            return .value(SubtensorSubnetNaming.isolatedLeftToRight(value))
        }

        return isPending ? .loading : .value(.subtensorUnknown(for: locale))
    }
}
