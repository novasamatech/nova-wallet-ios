import Foundation
import BigInt

struct GovernanceDelegateState {
    let maxLockedAmount: BigUInt
    let undelegatingPeriod: Moment?
}

struct GovernanceDelegateStateDiff {
    let before: GovernanceDelegateState
    let delegation: GovernanceNewDelegation?
    let after: GovernanceDelegateState?
}
