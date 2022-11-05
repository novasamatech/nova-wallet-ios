import Foundation

final class Gov1LocalMappingFactory {
    private func mapOngoing(
        referendum: Democracy.OngoingStatus,
        index: Referenda.ReferendumIndex,
        additionalInfo: Gov1OperationFactory.AdditionalInfo
    ) -> ReferendumLocal {
        let track = GovernanceTrackLocal(trackId: Gov1OperationFactory.trackId, name: Gov1OperationFactory.trackName)

        let submitted = referendum.end - additionalInfo.votingPeriod

        let voting = VotingThresholdLocal(
            ayes: referendum.tally.ayes,
            nays: referendum.tally.nays,
            turnout: referendum.tally.turnout,
            electorate: additionalInfo.totalIssuance,
            thresholdFunction: Gov1DecidingFunction(thresholdType: referendum.threshold)
        )

        let state = ReferendumStateLocal.Deciding(
            track: track,
            proposal: .unknown,
            voting: .threshold(voting),
            submitted: submitted,
            since: submitted,
            period: additionalInfo.votingPeriod,
            confirmationUntil: nil,
            deposit: nil
        )

        return .init(index: ReferendumIdLocal(index), state: .deciding(model: state), proposer: nil)
    }

    private func mapFinished(
        referendum: Democracy.FinishedStatus,
        index: Referenda.ReferendumIndex,
        additionalInfo: Gov1OperationFactory.AdditionalInfo
    ) -> ReferendumLocal {
        if referendum.approved {
            let approved = ReferendumStateLocal.Approved(
                since: referendum.end,
                whenEnactment: referendum.end + additionalInfo.enactmentPeriod,
                deposit: nil
            )
            return .init(index: ReferendumIdLocal(index), state: .approved(model: approved), proposer: nil)
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
        additionalInfo: Gov1OperationFactory.AdditionalInfo
    ) -> ReferendumLocal? {
        switch referendum {
        case let .ongoing(status):
            return mapOngoing(referendum: status, index: index, additionalInfo: additionalInfo)
        case let .finished(status):
            return mapFinished(referendum: status, index: index, additionalInfo: additionalInfo)
        case .unknown:
            return nil
        }
    }
}
