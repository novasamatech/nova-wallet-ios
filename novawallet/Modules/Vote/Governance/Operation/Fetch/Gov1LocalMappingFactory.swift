import Foundation
import BigInt

final class Gov1LocalMappingFactory {
    private func mapOngoing(
        referendum: Democracy.OngoingStatus,
        index: Referenda.ReferendumIndex,
        additionalInfo: Gov1OperationFactory.AdditionalInfo
    ) -> ReferendumLocal {
        let track = GovernanceTrackLocal(
            trackId: TrackIdLocal(Gov1OperationFactory.trackId),
            name: Gov1OperationFactory.trackName,
            totalTracksCount: 1
        )

        let submitted = referendum.end - additionalInfo.votingPeriod

        let voting = VotingThresholdLocal(
            ayes: referendum.tally.ayes,
            nays: referendum.tally.nays,
            turnout: referendum.tally.turnout,
            electorate: additionalInfo.electorate,
            thresholdFunction: Gov1DecidingFunction(thresholdType: referendum.threshold)
        )

        let state = ReferendumStateLocal.Deciding(
            track: track,
            proposal: referendum.universalProposal,
            voting: .threshold(voting),
            submitted: submitted,
            since: submitted,
            period: additionalInfo.votingPeriod,
            confirmationUntil: referendum.end,
            deposit: nil
        )

        return .init(index: ReferendumIdLocal(index), state: .deciding(model: state), proposer: nil)
    }

    private func mapFinished(
        referendum: Democracy.FinishedStatus,
        index: Referenda.ReferendumIndex,
        enactmentBlock: BlockNumber?
    ) -> ReferendumLocal {
        if referendum.approved {
            if let enactmentBlock = enactmentBlock {
                let approved = ReferendumStateLocal.Approved(
                    since: referendum.end,
                    whenEnactment: enactmentBlock,
                    deposit: nil
                )

                return .init(index: ReferendumIdLocal(index), state: .approved(model: approved), proposer: nil)
            } else {
                return .init(index: ReferendumIdLocal(index), state: .executed, proposer: nil)
            }
        } else {
            let rejected = ReferendumStateLocal.NotApproved(
                atBlock: referendum.end,
                deposit: nil
            )
            return .init(index: ReferendumIdLocal(index), state: .rejected(model: rejected), proposer: nil)
        }
    }
}

extension Gov1LocalMappingFactory {
    func mapRemote(
        referendum: Democracy.ReferendumInfo,
        index: Referenda.ReferendumIndex,
        additionalInfo: Gov1OperationFactory.AdditionalInfo,
        enactmentBlock: BlockNumber?
    ) -> ReferendumLocal? {
        switch referendum {
        case let .ongoing(status):
            return mapOngoing(referendum: status, index: index, additionalInfo: additionalInfo)
        case let .finished(status):
            return mapFinished(
                referendum: status,
                index: index,
                enactmentBlock: enactmentBlock
            )
        case .unknown:
            return nil
        }
    }

    func mapToTracksVoting(
        _ voting: Democracy.Voting?,
        lockedBalance: BigUInt?,
        maxVotes: UInt32
    ) -> ReferendumTracksVotingDistribution {
        let accountVoting = mapToAccountVoting(voting, maxVotes: maxVotes)

        let trackId = Gov1OperationFactory.trackId

        if let lockedBalance = lockedBalance, lockedBalance > 0 {
            let trackLock = ConvictionVoting.ClassLock(trackId: trackId, amount: lockedBalance)
            return .init(votes: accountVoting, trackLocks: [trackLock])
        } else {
            return .init(votes: accountVoting, trackLocks: [])
        }
    }

    func mapToAccountVoting(
        _ voting: Democracy.Voting?,
        maxVotes: UInt32
    ) -> ReferendumAccountVotingDistribution {
        let initVotingLocal = ReferendumAccountVotingDistribution(maxVotesPerTrack: maxVotes)

        if let voting = voting {
            let track = TrackIdLocal(Gov1OperationFactory.trackId)
            switch voting {
            case let .direct(castingVoting):
                return castingVoting.votes.reduce(initVotingLocal) { result, vote in
                    let newResult = result.addingReferendum(ReferendumIdLocal(vote.pollIndex), track: track)

                    guard let localVote = ReferendumAccountVoteLocal(accountVote: vote.accountVote) else {
                        return newResult
                    }

                    return newResult.addingVote(localVote, referendumId: ReferendumIdLocal(vote.pollIndex))
                }.addingPriorLock(castingVoting.prior, track: track)
            case let .delegating(delegatingVoting):
                let delegatingLocal = ReferendumDelegatingLocal(remote: delegatingVoting)
                return initVotingLocal.addingDelegating(delegatingLocal, trackId: track)
            case .unknown:
                return initVotingLocal
            }
        } else {
            return initVotingLocal
        }
    }
}
