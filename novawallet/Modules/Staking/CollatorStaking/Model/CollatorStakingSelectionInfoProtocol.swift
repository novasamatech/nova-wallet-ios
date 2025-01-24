import Foundation

protocol CollatorStakingSelectionInfoProtocol {
    var details: CollatorStakingSelectionInfoDetails? { get }
    var minRewardableStake: Balance { get }
    var apr: Decimal? { get }
    var totalStake: Balance { get }
    var ownStake: Balance { get }
    var delegatorsStake: Balance { get }
    var accountId: AccountId { get }
    var identity: AccountIdentity? { get }
    var maxRewardedDelegations: UInt32 { get }
    var delegationCount: UInt32 { get }

    func status(for selectedAccountId: AccountId, stake: Balance) -> CollatorStakingDelegationStatus
}

struct CollatorStakingSelectionInfoDetails {
    let delegations: [StakingStake]
}
