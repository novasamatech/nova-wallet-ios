import Foundation
import BigInt

struct CollatorSelectionInfo {
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

    var ownStake: BigUInt {
        metadata.bond
    }

    var delegatorsStake: BigUInt {
        totalStake > ownStake ? totalStake - ownStake : 0
    }
}

extension Array where Self.Element == CollatorSelectionInfo {
    func identitiesDict() -> [AccountId: AccountIdentity] {
        reduce(into: [AccountId: AccountIdentity]()) { result, item in
            if let identity = item.identity {
                result[item.accountId] = identity
            }
        }
    }
}

extension CollatorSelectionInfo: CollatorStakingSelectionInfoProtocol {
    var delegationCount: UInt32 { metadata.delegationCount }

    func status(for selectedAccountId: AccountId, stake: BigUInt) -> CollatorStakingDelegationStatus {
        guard let details else {
            return .notElected
        }

        if details.delegations.contains(where: { $0.owner == selectedAccountId }) {
            return .rewarded
        }

        if metadata.isStakeShouldBeActive(for: stake) {
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
