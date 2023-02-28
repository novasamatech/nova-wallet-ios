import Foundation

struct GovernanceUnlocksViewModel {
    enum ClaimState {
        case now
        case afterPeriod(time: String)
        case delegation
    }

    struct Item {
        let amount: String
        let claimState: ClaimState
    }

    let total: BalanceViewModelProtocol
    let items: [Item]
}
