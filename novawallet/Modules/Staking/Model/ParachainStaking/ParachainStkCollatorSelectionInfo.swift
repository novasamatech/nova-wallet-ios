import Foundation
import BigInt

struct ParachainStkCollatorSelectionInfo {
    let accountId: AccountId
    let metadata: ParachainStaking.CandidateMetadata
    let details: CollatorStakingSelectionInfoDetails?
    let identity: AccountIdentity?
    let apr: Decimal?
    let commission: BigUInt
    let minTechStake: BigUInt
    let maxRewardedDelegations: UInt32

    var minRewardableStake: BigUInt {
        metadata.minRewardableStake(for: minTechStake)
    }

    var totalStake: BigUInt {
        metadata.totalCounted
    }

    var ownStake: BigUInt? {
        metadata.bond
    }

    var delegatorsStake: BigUInt {
        metadata.totalCounted.subtractOrZero(metadata.bond)
    }
}

extension Array where Self.Element == ParachainStkCollatorSelectionInfo {
    func identitiesDict() -> [AccountId: AccountIdentity] {
        reduce(into: [AccountId: AccountIdentity]()) { result, item in
            if let identity = item.identity {
                result[item.accountId] = identity
            }
        }
    }
}

extension ParachainStkCollatorSelectionInfo: CollatorStakingSelectionInfoProtocol {
    var delegationCount: UInt32 { metadata.delegationCount }

    var isElected: Bool { details != nil }

    func status(
        for delegatorAccountId: AccountId,
        delegatorModel: CollatorStakingDelegator?,
        stake: Balance
    ) -> CollatorStakingDelegationStatus {
        guard let details else {
            return .notElected
        }

        if details.delegations.contains(where: { $0.owner == delegatorAccountId }) {
            return .rewarded
        }

        if
            let delegations = delegatorModel?.delegations,
            delegations.contains(where: { $0.candidate == accountId }),
            metadata.isStakeShouldBeActive(for: stake) {
            return .pending
        }

        return .notRewarded
    }
}

extension CollatorStakingSelectionInfoDetails {
    init?(parachainInfo: ParachainStaking.CollatorSnapshot?) {
        guard let parachainInfo else {
            return nil
        }

        delegations = parachainInfo.delegations.map {
            StakingStake(owner: $0.owner, amount: $0.amount)
        }
    }
}
