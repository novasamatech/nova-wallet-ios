import Foundation
import BigInt

struct ReferendumLocal {
    let index: UInt
    let state: ReferendumStateLocal
}

struct SupportAndVotesLocal {
    let ayes: BigUInt
    let nays: BigUInt
    let support: BigUInt
}

enum ReferendumStateLocal {
    enum Voting {
        case supportAndVotes(model: SupportAndVotesLocal)
    }

    struct Deciding {
        let trackId: UInt16
        let voting: Voting
        let since: BlockNumber
        let period: Moment
        let confirmationUntil: BlockNumber?
    }

    struct Preparing {
        let trackId: UInt16
        let voting: Voting
        let deposit: BigUInt?
        let since: BlockNumber
        let period: Moment
        let inQueue: Bool
    }

    case preparing(model: Preparing)
    case deciding(model: Deciding)
    case approved(atBlock: Moment)
    case rejected(atBlock: Moment)
    case cancelled(atBlock: Moment)
    case timedOut(atBlock: Moment)
    case killed(atBlock: Moment)
    case executed

    var completed: Bool {
        switch self {
        case .preparing, .deciding:
            return false
        case .approved, .rejected, .cancelled, .timedOut, .killed, .executed:
            return true
        }
    }
}
