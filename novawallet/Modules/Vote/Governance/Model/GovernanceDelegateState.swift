import Foundation
import BigInt

struct GovernanceDelegateState {
    let maxLockedAmount: BigUInt
    let delegatedUntil: BlockNumber?
}

struct GovernanceDelegateStateDiff {
    let before: GovernanceDelegateState
    let vote: GovernanceNewDelegation?
    let after: GovernanceDelegateState?
}
