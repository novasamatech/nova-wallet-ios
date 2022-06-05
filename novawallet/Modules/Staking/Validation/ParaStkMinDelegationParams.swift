import Foundation
import BigInt

struct ParaStkMinDelegationParams {
    let minDelegation: BigUInt?
    let minDelegatorStake: BigUInt?
    let delegationsCount: Int?

    var atLeastAtStake: BigUInt? {
        if
            let minDelegation = minDelegation,
            let minDelegatorStake = minDelegatorStake,
            let delegationCount = delegationsCount {
            return delegationCount == 1 ? max(minDelegation, minDelegatorStake) : minDelegation
        } else {
            return nil
        }
    }
}
