import Foundation
import SubstrateSdk

final class Gov2ExtrinsicFactory: GovernanceExtrinsicFactory, GovernanceExtrinsicFactoryProtocol {
    func vote(
        _ action: ReferendumVoteAction,
        referendum: ReferendumIdLocal,
        builder: ExtrinsicBuilderProtocol
    ) throws -> ExtrinsicBuilderProtocol {
        let accountVote = AccountVoteFactory.accountVote(from: action)

        let voteCall = ConvictionVoting.VoteCall(
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

            return ConvictionVoting.VoteCall(
                referendumIndex: Referenda.ReferendumIndex(vote.index),
                vote: accountVote
            ).runtimeCall
        }

        return voteCalls.reduce(splitter) { $0.adding(call: $1) }
    }

    func unlock(
        with actions: Set<GovernanceUnlockSchedule.Action>,
        accountId: AccountId,
        splitter: ExtrinsicSplitting
    ) throws -> ExtrinsicSplitting {
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

        let newSplitter = removeVoteCalls.reduce(splitter) { $0.adding(call: $1) }
        return unlockCalls.reduce(newSplitter) { $0.adding(call: $1) }
    }

    func delegationUpdate(
        with actions: [GovernanceDelegatorAction],
        splitter: ExtrinsicSplitting
    ) throws -> ExtrinsicSplitting {
        actions.reduce(splitter) { _, action in
            switch action.type {
            case let .delegate(model):
                return splitter.adding(
                    call: ConvictionVoting.DelegateCall(
                        track: Referenda.TrackId(action.trackId),
                        delegateAddress: .accoundId(action.delegateId),
                        conviction: model.conviction,
                        balance: model.balance
                    ).runtimeCall
                )
            case .undelegate:
                return splitter.adding(
                    call: ConvictionVoting.UndelegateCall(
                        track: Referenda.TrackId(action.trackId)
                    ).runtimeCall
                )
            }
        }
    }
}
