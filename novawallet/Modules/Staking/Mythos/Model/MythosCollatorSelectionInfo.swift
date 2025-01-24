import Foundation

struct MythosCollatorSelectionInfo {
    let accountId: AccountId
    let candidate: MythosStakingPallet.CandidateInfo
    let identity: AccountIdentity?
    let maxRewardedDelegations: UInt32
    let minRewardableStake: Balance
    let isElected: Bool
    let apr: Decimal?
}

extension MythosCollatorSelectionInfo: CollatorStakingSelectionInfoProtocol {
    var totalStake: Balance { candidate.stake }
    var ownStake: Balance? { nil }
    var delegatorsStake: Balance { candidate.stake }
    var delegationCount: UInt32 { candidate.stakers }

    func status(
        for _: AccountId,
        delegatorModel: CollatorStakingDelegator?,
        stake _: Balance
    ) -> CollatorStakingDelegationStatus {
        guard isElected else {
            return .notElected
        }

        let hasDelegation = delegatorModel?.hasDelegation(to: accountId) ?? false

        return hasDelegation ? .rewarded : .notRewarded
    }
}
