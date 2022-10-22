import Foundation
import SubstrateSdk

final class Gov2ExtrinsicFactory: GovernanceExtrinsicFactoryProtocol {
    func vote(
        _ action: ReferendumVoteAction,
        referendum: ReferendumIdLocal,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let accountVote = ConvictionVoting.AccountVote.standard(
            .init(
                vote: .init(aye: action.isAye, conviction: action.conviction),
                balance: action.amount
            )
        )

        let voteCall = ConvictionVoting.VoteCall(
            referendumIndex: Referenda.ReferendumIndex(referendum),
            vote: accountVote
        )

        return try builder.adding(call: voteCall.runtimeCall)
    }
}
