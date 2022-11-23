import Foundation
import BigInt
import SubstrateSdk

typealias ReferendumIdLocal = UInt
typealias TrackIdLocal = UInt

struct ReferendumLocal {
    let index: ReferendumIdLocal
    let state: ReferendumStateLocal
    let proposer: AccountId?

    var canVote: Bool {
        switch state {
        case .preparing, .deciding:
            return true
        case .approved, .rejected, .cancelled, .timedOut, .killed, .executed:
            return false
        }
    }

    var trackId: TrackIdLocal? {
        track.map { TrackIdLocal($0.trackId) }
    }

    var track: GovernanceTrackLocal? {
        switch state {
        case let .preparing(model):
            return model.track
        case let .deciding(model):
            return model.track
        case .approved, .rejected, .cancelled, .timedOut, .killed, .executed:
            return nil
        }
    }

    var voting: ReferendumStateLocal.Voting? {
        switch state {
        case let .preparing(model):
            return model.voting
        case let .deciding(model):
            return model.voting
        case .approved, .rejected, .cancelled, .timedOut, .killed, .executed:
            return nil
        }
    }

    var deposit: BigUInt? {
        switch state {
        case let .preparing(model):
            return model.deposit
        case let .deciding(model):
            return model.deposit
        case let .approved(model):
            return model.deposit
        case let .rejected(model):
            return model.deposit
        case let .cancelled(model):
            return model.deposit
        case let .timedOut(model):
            return model.deposit
        case .killed, .executed:
            return nil
        }
    }
}

struct SupportAndVotesLocal {
    let ayes: BigUInt
    let nays: BigUInt
    let support: BigUInt
    let totalIssuance: BigUInt

    /// fraction of ayes
    var approvalFraction: Decimal? {
        guard
            let total = Decimal(ayes + nays), total > 0,
            let ayesDecimal = Decimal(ayes) else {
            return nil
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
    let approvalFunction: ReferendumDecidingFunctionProtocol?
    let supportFunction: ReferendumDecidingFunctionProtocol?

    func isPassing(at block: BlockNumber) -> Bool {
        guard
            let approvalThreshold = approvalFunction?.calculateThreshold(for: block),
            let supportThreshold = supportFunction?.calculateThreshold(for: block),
            let approvalFraction = approvalFraction else {
            return false
        }

        return approvalFraction >= approvalThreshold && supportFraction >= supportThreshold
    }
}

struct VotingThresholdLocal {
    let ayes: BigUInt
    let nays: BigUInt
    let turnout: BigUInt
    let electorate: BigUInt

    /// fraction of ayes
    var approvalFraction: Decimal? {
        guard
            let total = Decimal(ayes + nays), total > 0,
            let ayesDecimal = Decimal(ayes) else {
            return nil
        }

        return ayesDecimal / total
    }

    let thresholdFunction: DemocracyDecidingFunctionProtocol

    func calculateThreshold() -> Decimal? {
        thresholdFunction.calculateThreshold(
            for: ayes,
            nays: nays,
            turnout: turnout,
            electorate: electorate
        )
    }

    func isPassing() -> Bool {
        if let threshold = calculateThreshold(), let approvalFraction = approvalFraction {
            return approvalFraction > threshold
        } else {
            return false
        }
    }
}

enum ReferendumStateLocal {
    enum Voting {
        case supportAndVotes(SupportAndVotesLocal)
        case threshold(VotingThresholdLocal)
    }

    struct Deciding {
        let track: GovernanceTrackLocal
        let proposal: Democracy.Proposal?
        let voting: Voting
        let submitted: BlockNumber
        let since: BlockNumber
        let period: Moment
        let confirmationUntil: BlockNumber?
        let deposit: BigUInt?

        var rejectedAt: BlockNumber {
            since + period
        }

        func isPassing(for currentBlock: BlockNumber) -> Bool {
            switch voting {
            case let .supportAndVotes(model):
                return model.isPassing(at: currentBlock)
            case let .threshold(model):
                return model.isPassing()
            }
        }
    }

    struct InQueuePosition {
        let index: Int
        let total: Int
    }

    struct Preparing {
        let track: GovernanceTrackLocal
        let proposal: SupportPallet.Bounded<RuntimeCall<JSON>>
        let voting: Voting
        let deposit: BigUInt?
        let since: BlockNumber
        let preparingPeriod: Moment
        let timeoutPeriod: Moment
        let inQueue: Bool
        let inQueuePosition: InQueuePosition?

        var preparingEnd: BlockNumber {
            since + preparingPeriod
        }

        var timeoutAt: BlockNumber {
            since + timeoutPeriod
        }
    }

    struct Approved {
        let since: BlockNumber
        let whenEnactment: BlockNumber?
        let deposit: BigUInt?
    }

    struct NotApproved {
        let atBlock: BlockNumber
        let deposit: BigUInt?
    }

    case preparing(model: Preparing)
    case deciding(model: Deciding)
    case approved(model: Approved)
    case rejected(model: NotApproved)
    case cancelled(model: NotApproved)
    case timedOut(model: NotApproved)
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

    var proposal: SupportPallet.Bounded<RuntimeCall<JSON>>? {
        switch self {
        case let .preparing(model):
            return model.proposal
        case let .deciding(model):
            return model.proposal
        case .approved, .rejected, .cancelled, .timedOut, .killed, .executed:
            return nil
        }
    }
}

struct GovernanceTrackLocal {
    let trackId: UInt16
    let name: String
    let totalTracksCount: Int
}
