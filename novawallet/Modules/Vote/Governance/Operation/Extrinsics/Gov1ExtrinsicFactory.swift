import Foundation
import SubstrateSdk

final class Gov1ExtrinsicFactory: GovernanceExtrinsicFactory, GovernanceExtrinsicFactoryProtocol {
    func vote(
        _ action: ReferendumVoteAction,
        referendum: ReferendumIdLocal,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let accountVote = AccountVoteFactory.accountVote(from: action)

        let voteCall = Democracy.VoteCall(
            referendumIndex: Referenda.ReferendumIndex(referendum),
            vote: accountVote
        )

        return try builder.adding(call: voteCall.runtimeCall)
    }

    func vote(
        using votes: [ReferendumNewVote],
        splitter: ExtrinsicSplitting
    ) -> ExtrinsicSplitting {
        let voteCalls = votes.map { vote in
            let accountVote = AccountVoteFactory.accountVote(from: vote.voteAction)

            return Democracy.VoteCall(
                referendumIndex: Referenda.ReferendumIndex(vote.index),
                vote: accountVote
            )
        }

        return voteCalls.reduce(splitter) { $0.adding(call: $1.runtimeCall) }
    }

    func unlock(
        with actions: Set<GovernanceUnlockSchedule.Action>,
        accountId: AccountId,
        splitter: ExtrinsicSplitting
    ) throws -> ExtrinsicSplitting {
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

        let newSplitter = removeVoteCalls.reduce(splitter) { $0.adding(call: $1) }
        return unlockCalls.reduce(newSplitter) { $0.adding(call: $1) }
    }

    func delegationUpdate(
        with _: [GovernanceDelegatorAction],
        splitter _: ExtrinsicSplitting
    ) throws -> ExtrinsicSplitting {
        fatalError("Not supported")
    }
}
