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

extension SubtensorRowState where Value == BalanceViewModelProtocol {
    static func trade(
        _ value: BalanceViewModelProtocol?,
        isPending: Bool,
        locale: Locale
    ) -> SubtensorRowState<BalanceViewModelProtocol> {
        if let value {
            return .value(
                BalanceViewModel(amount: SubtensorSubnetNaming.isolatedLeftToRight(value.amount), price: value.price)
            )
        }

        return isPending ? .loading : .value(BalanceViewModel(amount: .subtensorUnknown(for: locale), price: nil))
    }
}
