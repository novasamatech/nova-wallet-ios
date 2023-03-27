import Foundation
import BigInt

enum ReferendumAccountVoteLocal: Equatable {
    case split(ConvictionVoting.AccountVoteSplit)
    case standard(ConvictionVoting.AccountVoteStandard)
    case splitAbstain(ConvictionVoting.AccountVoteSplitAbstain)

    var hasAyeVotes: Bool {
        switch self {
        case let .split(voting):
            return voting.aye > 0
        case let .splitAbstain(voting):
            return voting.aye > 0
        case let .standard(voting):
            return voting.vote.aye
        }
    }

    var hasNayVotes: Bool {
        switch self {
        case let .split(voting):
            return voting.nay > 0
        case let .splitAbstain(voting):
            return voting.nay > 0
        case let .standard(voting):
            return !voting.vote.aye
        }
    }

    var hasAbstainVotes: Bool {
        switch self {
        case let .splitAbstain(voting):
            return voting.abstain > 0
        case .standard, .split:
            return false
        }
    }

    /// post conviction votes for referendum
    var ayes: BigUInt {
        switch self {
        case let .split(value):
            let conviction = ConvictionVoting.Conviction.none
            return conviction.votes(for: value.aye) ?? 0
        case let .splitAbstain(value):
            let conviction = ConvictionVoting.Conviction.none
            return conviction.votes(for: value.aye) ?? 0
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
            let conviction = ConvictionVoting.Conviction.none
            return conviction.votes(for: value.nay) ?? 0
        case let .splitAbstain(value):
            let conviction = ConvictionVoting.Conviction.none
            return conviction.votes(for: value.nay) ?? 0
        case let .standard(value):
            if !value.vote.aye {
                return value.vote.conviction.votes(for: value.balance) ?? 0
            } else {
                return 0
            }
        }
    }

    var abstains: BigUInt {
        switch self {
        case let .splitAbstain(value):
            let conviction = ConvictionVoting.Conviction.none
            return conviction.votes(for: value.abstain) ?? 0
        case .standard, .split:
            return 0
        }
    }

    var ayeBalance: BigUInt {
        switch self {
        case let .split(value):
            return value.aye
        case let .splitAbstain(value):
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
        case let .splitAbstain(value):
            return value.nay
        case let .standard(value):
            if !value.vote.aye {
                return value.balance
            } else {
                return 0
            }
        }
    }

    var abstainBalance: BigUInt {
        switch self {
        case let .splitAbstain(value):
            return value.abstain
        case .standard, .split:
            return 0
        }
    }

    var totalBalance: BigUInt {
        ayeBalance + nayBalance
    }

    var conviction: Decimal? {
        switch self {
        case .split, .splitAbstain:
            return 0.1
        case let .standard(value):
            return value.vote.conviction.decimalValue
        }
    }

    var convictionValue: ConvictionVoting.Conviction {
        switch self {
        case .split, .splitAbstain:
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
        case let .splitAbstain(splitAbstain):
            self = .splitAbstain(splitAbstain)
        case .unknown:
            return nil
        }
    }
}
