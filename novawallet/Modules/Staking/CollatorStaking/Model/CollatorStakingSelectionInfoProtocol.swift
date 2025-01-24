import Foundation

protocol CollatorStakingSelectionInfoProtocol {
    var minRewardableStake: Balance { get }
    var apr: Decimal? { get }
    var totalStake: Balance { get }
    var ownStake: Balance? { get }
    var delegatorsStake: Balance { get }
    var accountId: AccountId { get }
    var identity: AccountIdentity? { get }
    var maxRewardedDelegations: UInt32 { get }
    var delegationCount: UInt32 { get }

    var isElected: Bool { get }

    func status(
        for delegatorAccountId: AccountId,
        delegatorModel: CollatorStakingDelegator?,
        stake: Balance
    ) -> CollatorStakingDelegationStatus
}

struct CollatorStakingSelectionInfoDetails {
    let delegations: [StakingStake]
}
