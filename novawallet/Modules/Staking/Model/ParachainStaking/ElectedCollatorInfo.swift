import Foundation
import BigInt

struct ElectedCollatorInfo {
    let accountId: AccountId
    let snapshot: ParachainStaking.CollatorSnapshot
    let identity: AccountIdentity?
    let commission: BigUInt
    let maxDelegatorReward: UInt32

    var isFull: Bool {
        snapshot.delegations.count >= maxDelegatorReward
    }
}
