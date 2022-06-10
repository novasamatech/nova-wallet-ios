import Foundation
import BigInt

struct CollatorSelectionInfo {
    let accountId: AccountId
    let metadata: ParachainStaking.CandidateMetadata
    let snapshot: ParachainStaking.CollatorSnapshot?
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
