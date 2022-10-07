import Foundation
import BigInt

struct ReferendumAccountVoteLocal {
    /// post conviction votes for referendum
    let ayes: BigUInt
    let nays: BigUInt

    init?(accountVote: ConvictionVoting.AccountVote) {
        switch accountVote {
        case let .split(split):
            self.init(accountVoteSplit: split)
        case let .standard(standard):
            self.init(accountVoteStandard: standard)
        case .unknown:
            return nil
        }
    }

    init(accountVoteSplit: ConvictionVoting.AccountVoteSplit) {
        ayes = accountVoteSplit.aye
        nays = accountVoteSplit.nay
    }

    init?(accountVoteStandard: ConvictionVoting.AccountVoteStandard) {
        guard let votes = accountVoteStandard.vote.conviction.votes(for: accountVoteStandard.balance) else {
            return nil
        }

        if accountVoteStandard.vote.aye {
            ayes = votes
            nays = 0
        } else {
            ayes = 0
            nays = votes
        }
    }
}
