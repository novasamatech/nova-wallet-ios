import Foundation
import BigInt

enum ReferendumAccountVoteLocal {
    case split(ConvictionVoting.AccountVoteSplit)
    case standard(ConvictionVoting.AccountVoteStandard)

    /// post conviction votes for referendum
    var ayes: BigUInt {
        switch self {
        case let .split(value):
            return value.aye
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
            return value.nay
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
            return 1
        case let .standard(value):
            return value.vote.conviction.decimalValue
        }
    }

    var convictionValue: ConvictionVoting.Conviction {
        switch self {
        case .split:
            return .locked1x
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
