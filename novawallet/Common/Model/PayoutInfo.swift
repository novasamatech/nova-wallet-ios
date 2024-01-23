import Foundation

struct PayoutsInfo {
    let activeEra: EraIndex
    let historyDepth: UInt32
    let payouts: [PayoutInfo]
}

struct PayoutInfo: Hashable {
    let validator: AccountId
    let era: EraIndex
    let pages: Set<Staking.ValidatorPage>
    let reward: Decimal
    let identity: AccountIdentity?
}
