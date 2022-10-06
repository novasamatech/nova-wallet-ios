import Foundation

final class Gov2LocalMappingFactory {
    private func createOngoingReferendumState(
        from status: ReferendumInfo.OngoingStatus,
        index: Referenda.ReferendumIndex,
        track: Referenda.TrackInfo
    ) -> ReferendumLocal {
        let state: ReferendumStateLocal

        let votes = SupportAndVotesLocal(
            ayes: status.tally.ayes,
            nays: status.tally.nays,
            support: status.tally.support
        )

        let localTrack = GovernanceTrackLocal(trackId: status.track, name: track.name)

        if let deciding = status.deciding {
            let model = ReferendumStateLocal.Deciding(
                track: localTrack,
                voting: .supportAndVotes(model: votes),
                since: deciding.since,
                period: track.decisionPeriod,
                confirmationUntil: deciding.confirming
            )

            state = .deciding(model: model)
        } else {
            let preparing = ReferendumStateLocal.Preparing(
                track: localTrack,
                voting: .supportAndVotes(model: votes),
                deposit: status.decisionDeposit?.amount,
                since: status.submitted,
                period: track.preparePeriod,
                inQueue: status.inQueue
            )

            state = .preparing(model: preparing)
        }

        return ReferendumLocal(
            index: UInt(index),
            state: state
        )
    }

    func mapRemote(
        referendum: ReferendumInfo,
        index: Referenda.ReferendumIndex,
        tracks: [Referenda.TrackId: Referenda.TrackInfo]
    ) -> ReferendumLocal? {
        switch referendum {
        case let .ongoing(status):
            guard let track = tracks[status.track] else {
                return nil
            }

            return createOngoingReferendumState(from: status, index: index, track: track)
        case let .approved(status):
            return ReferendumLocal(index: UInt(index), state: .approved(atBlock: status.since))
        case let .rejected(status):
            return ReferendumLocal(index: UInt(index), state: .rejected(atBlock: status.since))
        case let .timedOut(status):
            return ReferendumLocal(index: UInt(index), state: .timedOut(atBlock: status.since))
        case let .cancelled(status):
            return ReferendumLocal(index: UInt(index), state: .cancelled(atBlock: status.since))
        case let .killed(atBlock):
            return ReferendumLocal(index: UInt(index), state: .killed(atBlock: atBlock))
        case .unknown:
            return nil
        }
    }
}
