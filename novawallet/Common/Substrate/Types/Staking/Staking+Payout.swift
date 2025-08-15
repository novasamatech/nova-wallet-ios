import Foundation

extension Staking {
    struct PayoutsInfo {
        let activeEra: Staking.EraIndex
        let historyDepth: UInt32
        let payouts: [PayoutInfo]
    }

    struct PayoutInfo: Hashable {
        let validator: AccountId
        let era: Staking.EraIndex
        let pages: Set<Staking.ValidatorPage>
        let reward: Decimal
        let identity: AccountIdentity?
    }
}
