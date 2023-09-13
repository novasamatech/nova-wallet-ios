import Foundation
import BigInt

struct RelaychainStakingRestrictions {
    let minJoinStake: BigUInt?
    let minRewardableStake: BigUInt?
    let allowsNewStakers: Bool
}
