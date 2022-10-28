import Foundation
import BigInt

enum ReferendumAccountVoteLocal {
    case split(ConvictionVoting.AccountVoteSplit)
    case standard(ConvictionVoting.AccountVoteStandard)

    var hasAyeVotes: Bool {
        switch self {
        case let .split(voting):
            return voting.aye > 0
        case let .standard(voting):
            return voting.vote.aye
        }
    }

    var hasNayVotes: Bool {
        switch self {
        case let .split(voting):
            return voting.nay > 0
        case let .standard(voting):
            return !voting.vote.aye
        }
    }

    /// post conviction votes for referendum
    var ayes: BigUInt {
        switch self {
        case let .split(value):
            let splitConviction = ConvictionVoting.Conviction.none
            return splitConviction.votes(for: value.aye) ?? 0
        case let .standard(value):
            if value.vote.aye {
                return value.vote.conviction.votes(for: value.balance) ?? 0
            } else {
                return 0
            }
        }
    }

    var nays: BigUInt {
        switch self {
        case let .split(value):
            let splitConviction = ConvictionVoting.Conviction.none
            return splitConviction.votes(for: value.nay) ?? 0
        case let .standard(value):
            if !value.vote.aye {
                return value.vote.conviction.votes(for: value.balance) ?? 0
            } else {
                return 0
            }
        }
    }

    var ayeBalance: BigUInt {
        switch self {
        case let .split(value):
            return value.aye
        case let .standard(value):
            if value.vote.aye {
                return value.balance
            } else {
                return 0
            }
        }
    }

    var nayBalance: BigUInt {
        switch self {
        case let .split(value):
            return value.nay
        case let .standard(value):
            if !value.vote.aye {
                return value.balance
            } else {
                return 0
            }
        }
    }

    var totalBalance: BigUInt {
        ayeBalance + nayBalance
    }

    var conviction: Decimal? {
        switch self {
        case .split:
            return 0.1
        case let .standard(value):
            return value.vote.conviction.decimalValue
        }
    }

    var convictionValue: ConvictionVoting.Conviction {
        switch self {
        case .split:
            return .none
        case let .standard(voting):
            return voting.vote.conviction
        }
    }

    init?(accountVote: ConvictionVoting.AccountVote) {
        switch accountVote {
        case let .split(split):
            self = .split(split)
        case let .standard(standard):
            self = .standard(standard)
        case .unknown:
            return nil
        }
    }
}
