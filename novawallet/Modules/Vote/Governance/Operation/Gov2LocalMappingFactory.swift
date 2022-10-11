import Foundation

final class Gov2LocalMappingFactory {
    private func createDecidingState(
        from status: ReferendumInfo.OngoingStatus,
        deciding: ReferendumInfo.DecidingStatus,
        track: Referenda.TrackInfo,
        additionalInfo: Gov2OperationFactory.AdditionalInfo
    ) -> ReferendumStateLocal {
        let approvalFunction = Gov2LocalDecidingFunction(
            curve: track.minApproval,
            startBlock: deciding.since,
            period: track.decisionPeriod
        )

        let supportFunction = Gov2LocalDecidingFunction(
            curve: track.minSupport,
            startBlock: deciding.since,
            period: track.decisionPeriod
        )

        let votes = SupportAndVotesLocal(
            ayes: status.tally.ayes,
            nays: status.tally.nays,
            support: status.tally.support,
            totalIssuance: additionalInfo.totalIssuance,
            approvalFunction: approvalFunction,
            supportFunction: supportFunction
        )

        let localTrack = GovernanceTrackLocal(trackId: status.track, name: track.name)

        let model = ReferendumStateLocal.Deciding(
            track: localTrack,
            proposal: status.proposal,
            voting: .supportAndVotes(model: votes),
            since: deciding.since,
            period: track.decisionPeriod,
            confirmationUntil: deciding.confirming
        )

        return .deciding(model: model)
    }

    private func createPreparingState(
        from status: ReferendumInfo.OngoingStatus,
        track: Referenda.TrackInfo,
        additionalInfo: Gov2OperationFactory.AdditionalInfo
    ) -> ReferendumStateLocal {
        let votes = SupportAndVotesLocal(
            ayes: status.tally.ayes,
            nays: status.tally.nays,
            support: status.tally.support,
            totalIssuance: additionalInfo.totalIssuance,
            approvalFunction: nil,
            supportFunction: nil
        )

        let localTrack = GovernanceTrackLocal(trackId: status.track, name: track.name)

        let preparing = ReferendumStateLocal.Preparing(
            track: localTrack,
            proposal: status.proposal,
            voting: .supportAndVotes(model: votes),
            deposit: status.decisionDeposit?.amount,
            since: status.submitted,
            preparingPeriod: track.preparePeriod,
            timeoutPeriod: additionalInfo.undecidingTimeout,
            inQueue: status.inQueue
        )

        return .preparing(model: preparing)
    }

    private func createOngoingReferendumState(
        from status: ReferendumInfo.OngoingStatus,
        index: Referenda.ReferendumIndex,
        additionalInfo: Gov2OperationFactory.AdditionalInfo
    ) -> ReferendumLocal? {
        guard let track = additionalInfo.tracks[status.track] else {
            return nil
        }

        let state: ReferendumStateLocal

        if let deciding = status.deciding {
            state = createDecidingState(
                from: status,
                deciding: deciding,
                track: track,
                additionalInfo: additionalInfo
            )
        } else {
            state = createPreparingState(
                from: status,
                track: track,
                additionalInfo: additionalInfo
            )
        }

        return ReferendumLocal(index: UInt(index), state: state, proposer: status.submissionDeposit.who)
    }

    func mapRemote(
        referendum: ReferendumInfo,
        index: Referenda.ReferendumIndex,
        additionalInfo: Gov2OperationFactory.AdditionalInfo,
        enactmentBlock: BlockNumber?
    ) -> ReferendumLocal? {
        switch referendum {
        case let .ongoing(status):
            return createOngoingReferendumState(from: status, index: index, additionalInfo: additionalInfo)
        case let .approved(status):
            let model = ReferendumStateLocal.Approved(since: status.since, whenEnactment: enactmentBlock)
            return ReferendumLocal(
                index: UInt(index),
                state: .approved(model: model),
                proposer: status.submissionDeposit.who
            )
        case let .rejected(status):
            return ReferendumLocal(
                index: UInt(index),
                state: .rejected(atBlock: status.since),
                proposer: status.submissionDeposit.who
            )
        case let .timedOut(status):
            return ReferendumLocal(
                index: UInt(index),
                state: .timedOut(atBlock: status.since),
                proposer: status.submissionDeposit.who
            )
        case let .cancelled(status):
            return ReferendumLocal(
                index: UInt(index),
                state: .cancelled(atBlock: status.since),
                proposer: status.submissionDeposit.who
            )
        case let .killed(atBlock):
            return ReferendumLocal(index: UInt(index), state: .killed(atBlock: atBlock), proposer: nil)
        case .unknown:
            return nil
        }
    }
}
