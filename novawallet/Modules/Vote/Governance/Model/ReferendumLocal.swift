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
    let totalIssuance: BigUInt

    /// fraction of ayes
    var approvalFraction: Decimal {
        guard
            let total = Decimal(ayes + nays), total > 0,
            let ayesDecimal = Decimal(ayes) else {
            return 0.0
        }

        return ayesDecimal / total
    }

    /// fraction of voted tokens
    var supportFraction: Decimal {
        guard
            let totalDecimal = Decimal(totalIssuance), totalDecimal > 0,
            let supportDecimal = Decimal(support) else {
            return 0.0
        }

        return supportDecimal / totalDecimal
    }

    /// nil if not deciding yet
    let approvalFunction: ReferendumLocalDecidingFunction?
    let supportFunction: ReferendumLocalDecidingFunction?

    func isPassing(at block: BlockNumber) -> Bool {
        guard
            let approvalThreshold = approvalFunction?.calculateThreshold(for: block),
            let supportThreshold = supportFunction?.calculateThreshold(for: block) else {
            return false
        }

        return approvalFraction >= approvalThreshold && supportFraction >= supportThreshold
    }
}

enum ReferendumStateLocal {
    enum Voting {
        case supportAndVotes(model: SupportAndVotesLocal)
    }

    struct Deciding {
        let track: GovernanceTrackLocal
        let voting: Voting
        let since: BlockNumber
        let period: Moment
        let confirmationUntil: BlockNumber?
    }

    struct Preparing {
        let track: GovernanceTrackLocal
        let voting: Voting
        let deposit: BigUInt?
        let since: BlockNumber
        let preparingPeriod: Moment
        let timeoutPeriod: Moment
        let inQueue: Bool
    }

    struct Approved {
        let since: BlockNumber
        let whenEnactment: BlockNumber?
    }

    case preparing(model: Preparing)
    case deciding(model: Deciding)
    case approved(model: Approved)
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

struct GovernanceTrackLocal {
    let trackId: UInt16
    let name: String
}
