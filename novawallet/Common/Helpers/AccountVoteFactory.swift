import Foundation

final class AccountVoteFactory {
    static func accountVote(from action: ReferendumVoteAction) -> ConvictionVoting.AccountVote {
        switch action {
        case let .aye(model), let .nay(model):
            .standard(
                .init(
                    vote: .init(voteAction: action),
                    balance: model.amount
                )
            )
        case let .abstain(model):
            .splitAbstain(
                .init(
                    aye: 0,
                    nay: 0,
                    abstain: model.amount
                )
            )
        }
    }

    static func accountVoteLocal(from action: ReferendumVoteAction) -> ReferendumAccountVoteLocal {
        switch action {
        case let .aye(model), let .nay(model):
            .standard(
                .init(
                    vote: .init(voteAction: action),
                    balance: model.amount
                )
            )
        case let .abstain(model):
            .splitAbstain(
                .init(
                    aye: 0,
                    nay: 0,
                    abstain: model.amount
                )
            )
        }
    }
}
