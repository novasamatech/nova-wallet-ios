import Foundation

struct ReferendumNewVote {
    let index: ReferendumIdLocal
    let voteAction: ReferendumVoteAction

    func toAccountVote() -> ReferendumAccountVoteLocal {
        .standard(
            .init(
                vote: .init(
                    aye: voteAction.isAye,
                    conviction: voteAction.conviction
                ),
                balance: voteAction.amount
            )
        )
    }
}
