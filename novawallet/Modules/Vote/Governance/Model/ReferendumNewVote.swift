import Foundation

struct ReferendumNewVote {
    let index: ReferendumIdLocal
    let voteAction: ReferendumVoteAction

    func toAccountVote() -> ReferendumAccountVoteLocal {
        .standard(.init(voteAction: voteAction))
    }
}
