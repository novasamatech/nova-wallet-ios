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

    func unlock(
        with actions: Set<GovernanceUnlockSchedule.Action>,
        accountId: AccountId,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let removeVoteCalls: [RuntimeCall<ConvictionVoting.RemoveVoteCall>] = actions.compactMap { action in
            switch action {
            case let .unvote(track, index):
                return ConvictionVoting.RemoveVoteCall(
                    track: Referenda.TrackId(track),
                    index: Referenda.ReferendumIndex(index)
                ).runtimeCall
            case .unlock:
                return nil
            }
        }

        let unlockCalls: [RuntimeCall<ConvictionVoting.UnlockCall>] = actions.compactMap { action in
            switch action {
            case let .unlock(track):
                return ConvictionVoting.UnlockCall(
                    track: Referenda.TrackId(track),
                    target: .accoundId(accountId)
                ).runtimeCall
            case .unvote:
                return nil
            }
        }

        let newBuilder = try appendCalls(removeVoteCalls, builder: builder)

        return try appendCalls(unlockCalls, builder: newBuilder)
    }

    private func appendCalls<C: RuntimeCallable>(
        _ calls: [C],
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        try calls.reduce(builder) { try $0.adding(call: $1) }
    }
}
