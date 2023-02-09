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
        trackIds.map { trackId in
            var actions: [GovernanceDelegatorAction] = []

            if voting.votes.delegatings[trackId] != nil {
                actions.append(
                    .init(
                        delegateId: delegateId,
                        trackId: trackId,
                        type: .undelegate
                    )
                )
            }

            actions.append(
                .init(
                    delegateId: delegateId,
                    trackId: trackId,
                    type: .delegate(.init(balance: balance, conviction: conviction))
                )
            )

            return actions
        }.flatMap { $0 }
    }
}
