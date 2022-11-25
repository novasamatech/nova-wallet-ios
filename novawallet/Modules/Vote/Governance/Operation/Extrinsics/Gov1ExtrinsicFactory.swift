import Foundation
import SubstrateSdk

final class Gov1ExtrinsicFactory: GovernanceExtrinsicFactory, GovernanceExtrinsicFactoryProtocol {
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

        let voteCall = Democracy.VoteCall(
            referendumIndex: Referenda.ReferendumIndex(referendum),
            vote: accountVote
        )

        return try builder.adding(call: voteCall.runtimeCall)
    }

    func unlock(
        with actions: Set<GovernanceUnlockSchedule.Action>,
        accountId: AccountId,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let removeVoteCalls: [RuntimeCall<Democracy.RemoveVoteCall>] = actions.compactMap { action in
            switch action {
            case let .unvote(_, index):
                return Democracy.RemoveVoteCall(index: Referenda.ReferendumIndex(index)).runtimeCall
            case .unlock:
                return nil
            }
        }

        let unlockCalls: [RuntimeCall<Democracy.UnlockCall>] = actions.compactMap { action in
            switch action {
            case .unlock:
                return Democracy.UnlockCall(target: .accoundId(accountId)).runtimeCall
            case .unvote:
                return nil
            }
        }

        let newBuilder = try appendCalls(removeVoteCalls, builder: builder)

        return try appendCalls(unlockCalls, builder: newBuilder)
    }
}
