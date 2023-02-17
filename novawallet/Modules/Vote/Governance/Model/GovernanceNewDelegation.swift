import Foundation
import BigInt

struct GovernanceNewDelegation {
    let delegateId: AccountId
    let trackIds: Set<TrackIdLocal>
    let balance: BigUInt
    let conviction: ConvictionVoting.Conviction
}

extension GovernanceNewDelegation {
    func createActions(from voting: ReferendumTracksVotingDistribution) -> [GovernanceDelegatorAction] {
        let oldTracks = voting.votes.delegatings.filter { $0.value.target == delegateId }
        let oldTrackIds = Set(oldTracks.keys)

        return trackIds.union(oldTrackIds).map { trackId in
            var actions: [GovernanceDelegatorAction] = []

            if oldTrackIds.contains(trackId) {
                actions.append(
                    .init(
                        delegateId: delegateId,
                        trackId: trackId,
                        type: .undelegate
                    )
                )
            }

            if trackIds.contains(trackId) {
                actions.append(
                    .init(
                        delegateId: delegateId,
                        trackId: trackId,
                        type: .delegate(.init(balance: balance, conviction: conviction))
                    )
                )
            }

            return actions
        }.flatMap { $0 }
    }
}
