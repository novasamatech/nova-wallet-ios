import Foundation
import BigInt

struct GovernanceLockState {
    let maxLockedAmount: BigUInt
    let lockedUntil: BlockNumber?
}

struct GovernanceLockStateDiff {
    let before: GovernanceLockState
    let votes: [ReferendumIdLocal: ReferendumNewVote]?
    let after: GovernanceLockState?
}
