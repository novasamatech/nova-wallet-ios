import Foundation

struct MythosCollatorSelectionInfo {
    let accountId: AccountId
    let candidate: MythosStakingPallet.CandidateInfo
    let details: CollatorStakingSelectionInfoDetails?
    let identity: AccountIdentity?
    let maxRewardedDelegations: UInt32
    let minRewardableStake: Balance
    let apr: Decimal?
}

extension MythosCollatorSelectionInfo: CollatorStakingSelectionInfoProtocol {
    var totalStake: Balance { candidate.stake }
    var ownStake: Balance { 0 }
    var delegatorsStake: Balance { candidate.stake }
    var delegationCount: UInt32 { candidate.stakers }

    func status(
        for _: AccountId,
        stake _: Balance
    ) -> CollatorStakingDelegationStatus {
        // TODO: Separate reduced and detailed models
        .notElected
    }
}
