import Foundation

struct ReferendumNewVote {
    let index: ReferendumIdLocal
    let voteAction: ReferendumVoteAction

    func toAccountVote() -> ReferendumAccountVoteLocal {
        AccountVoteFactory.accountVoteLocal(from: voteAction)
    }
}
