import Foundation

struct StakingRewardViewModel {
    enum ValueState {
        case loading
        case loaded(_ value: String)

        var value: String? {
            switch self {
            case .loading:
                return nil
            case let .loaded(value):
                return value
            }
        }
    }

    let amount: ValueState
    let price: ValueState?
}
