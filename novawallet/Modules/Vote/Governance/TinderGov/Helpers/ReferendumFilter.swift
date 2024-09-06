import Operation_iOS

enum ReferendumFilter {
    struct VoteAvailable {
        let referendums: [ReferendumLocal]
        let accountVotes: ReferendumAccountVotingDistribution?

        func callAsFunction() -> [ReferendumLocal] {
            referendums.filter {
                guard let trackId = $0.trackId else {
                    return false
                }

                return $0.canVote
                    && (accountVotes?.votes[$0.index] == nil)
                    && (accountVotes?.delegatings[trackId] == nil)
            }
        }
    }

    struct VoteAvailableChanges {
        let accountVotes: ReferendumAccountVotingDistribution?

        func callAsFunction(changes: [DataProviderChange<ReferendumLocal>]) -> [DataProviderChange<ReferendumLocal>] {
            var criteria: (ReferendumLocal) -> Bool = {
                guard let trackId = $0.trackId else {
                    return false
                }

                return $0.canVote
                    && (accountVotes?.votes[$0.index] == nil)
                    && (accountVotes?.delegatings[trackId] == nil)
            }

            return changes.compactMap { change in
                switch change {
                case let .insert(newItem):
                    criteria(newItem) ? change : nil
                case let .update(updatedItem):
                    criteria(updatedItem) ? change : .delete(deletedIdentifier: "\(updatedItem.index)")
                case .delete:
                    change
                }
            }
        }
    }
}
