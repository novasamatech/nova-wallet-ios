import Foundation

struct ParaStkYieldBoostComparisonViewModel {
    struct Reward {
        let percent: String
        let amount: BalanceViewModelProtocol
    }

    let apr: Reward?
    let apy: Reward?
}

extension ParaStkYieldBoostComparisonViewModel {
    static var empty: ParaStkYieldBoostComparisonViewModel {
        ParaStkYieldBoostComparisonViewModel(apr: nil, apy: nil)
    }
}
