import Foundation
import BigInt

struct CollatorSelectionInfo {
    let accountId: AccountId
    let metadata: ParachainStaking.CandidateMetadata
    let snapshot: ParachainStaking.CollatorSnapshot?
    let identity: AccountIdentity?
    let apr: Decimal
    let commission: BigUInt
    let minTechStake: BigUInt

    var minRewardableStake: BigUInt {
        metadata.minRewardableStake(for: minTechStake)
    }

    var totalStake: BigUInt {
        metadata.totalCounted
    }

    var ownStake: BigUInt {
        metadata.bond
    }
}
