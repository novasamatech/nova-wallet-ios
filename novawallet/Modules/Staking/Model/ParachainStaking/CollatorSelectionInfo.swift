import Foundation
import BigInt

struct CollatorSelectionInfo {
    let accountId: AccountId
    let metadata: ParachainStaking.CandidateMetadata
    let snapshot: ParachainStaking.CollatorSnapshot?
    let identity: AccountIdentity?
    let apr: Decimal
    let commission: BigUInt

    var minStake: BigUInt {
        metadata.lowestTopDelegationAmount
    }

    var totalStake: BigUInt {
        metadata.totalCounted
    }

    var ownStake: BigUInt {
        metadata.bond
    }
}
