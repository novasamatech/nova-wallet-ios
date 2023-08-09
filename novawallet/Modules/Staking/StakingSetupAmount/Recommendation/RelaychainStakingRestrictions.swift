import Foundation
import BigInt

struct RelaychainStakingRestrictions: Equatable {
    let minJoinStake: BigUInt?
    let minRewardableStake: BigUInt?
    let allowsNewStakers: Bool
}
