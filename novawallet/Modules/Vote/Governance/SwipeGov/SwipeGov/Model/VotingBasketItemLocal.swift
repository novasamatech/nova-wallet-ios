import Foundation
import Operation_iOS
import BigInt

struct VotingBasketItemLocal: Equatable {
    enum VoteType: String {
        case aye
        case nay
        case abstain
    }

    let referendumId: ReferendumIdLocal
    let chainId: ChainModel.Id
    let metaId: String
    let amount: BigUInt
    let voteType: VoteType
    let conviction: VotingBasketConvictionLocal

    func mapToVote() -> ReferendumNewVote {
        let index = referendumId

        let referendumVoteAction = ReferendumVoteActionModel(
            amount: amount,
            conviction: .init(from: conviction)
        )

        let voteAction: ReferendumVoteAction = switch voteType {
        case .aye:
            .aye(referendumVoteAction)
        case .nay:
            .nay(referendumVoteAction)
        case .abstain:
            .abstain(amount: amount)
        }

        return ReferendumNewVote(
            index: index,
            voteAction: voteAction
        )
    }
}

extension VotingBasketItemLocal {
    func replacing(_ votingPower: VotingPowerLocal) -> Self {
        .init(
            referendumId: referendumId,
            chainId: chainId,
            metaId: metaId,
            amount: votingPower.amount,
            voteType: voteType,
            conviction: votingPower.conviction
        )
    }
}

extension VotingBasketItemLocal: Identifiable {
    static func identifier(
        from referendumId: ReferendumIdLocal,
        metaId: String,
        chainId: ChainModel.Id
    ) -> String {
        [
            String(referendumId),
            metaId,
            chainId
        ].joined(with: .dash)
    }

    var identifier: String {
        Self.identifier(
            from: referendumId,
            metaId: metaId,
            chainId: chainId
        )
    }
}

extension Array where Element == VotingBasketItemLocal {
    func mapToVotes() -> [ReferendumNewVote] {
        map { $0.mapToVote() }
    }
}

enum VotingBasketConvictionLocal: String {
    /// 0.1x votes, unlocked.
    case none
    /// 1x votes, locked for an enactment period following a successful vote.
    case locked1x
    /// 2x votes, locked for 2x enactment periods following a successful vote.
    case locked2x
    /// 3x votes, locked for 4x...
    case locked3x
    /// 4x votes, locked for 8x...
    case locked4x
    /// 5x votes, locked for 16x...
    case locked5x
    /// 6x votes, locked for 32x...
    case locked6x

    init(rawType: String) {
        if let knownType = Self(rawValue: rawType) {
            self = knownType
        } else {
            self = .none
        }
    }

    init(from voteConviction: ConvictionVoting.Conviction) {
        switch voteConviction {
        case .none, .unknown:
            self = .none
        case .locked1x:
            self = .locked1x
        case .locked2x:
            self = .locked2x
        case .locked3x:
            self = .locked3x
        case .locked4x:
            self = .locked4x
        case .locked5x:
            self = .locked5x
        case .locked6x:
            self = .locked6x
        }
    }

    func votes(for balance: BigUInt) -> BigUInt {
        switch self {
        case .none:
            return balance / 10
        case .locked1x:
            return balance
        case .locked2x:
            return 2 * balance
        case .locked3x:
            return 3 * balance
        case .locked4x:
            return 4 * balance
        case .locked5x:
            return 5 * balance
        case .locked6x:
            return 6 * balance
        }
    }

    func conviction(for period: Moment) -> Moment {
        switch self {
        case .none:
            return 0
        case .locked1x:
            return period
        case .locked2x:
            return 2 * period
        case .locked3x:
            return 4 * period
        case .locked4x:
            return 8 * period
        case .locked5x:
            return 16 * period
        case .locked6x:
            return 32 * period
        }
    }

    var decimalValue: Decimal? {
        switch self {
        case .none:
            return 0.1
        case .locked1x:
            return 1
        case .locked2x:
            return 2
        case .locked3x:
            return 3
        case .locked4x:
            return 4
        case .locked5x:
            return 5
        case .locked6x:
            return 6
        }
    }
}

extension ConvictionVoting.Conviction {
    init(from convictionLocal: VotingBasketConvictionLocal) {
        switch convictionLocal {
        case .none:
            self = .none
        case .locked1x:
            self = .locked1x
        case .locked2x:
            self = .locked2x
        case .locked3x:
            self = .locked3x
        case .locked4x:
            self = .locked4x
        case .locked5x:
            self = .locked5x
        case .locked6x:
            self = .locked6x
        }
    }
}
