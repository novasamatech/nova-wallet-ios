import Foundation
import BigInt
@testable import novawallet

final class GovernanceTestBuilder {
    struct TrackVoting {
        let trackId: TrackIdLocal
        let locked: BigUInt
        let votes: [ReferendumIdLocal: ReferendumAccountVoteLocal]
        let prior: ConvictionVoting.PriorLock
        let delegating: ConvictionVoting.Delegating?

        func byChangingLocked(_ locked: BigUInt) -> TrackVoting {
            TrackVoting(
                trackId: trackId,
                locked: locked,
                votes: votes,
                prior: prior,
                delegating: delegating
            )
        }
    }

    @resultBuilder
    class TrackVotingBuilder {
        private var voting: TrackVoting

        init(trackId: TrackIdLocal) {
            voting = TrackVoting(
                trackId: trackId,
                locked: 0,
                votes: [:],
                prior: .notExisting,
                delegating: nil
            )
        }

        func locked(_ amount: BigUInt) -> TrackVoting {
            voting = voting.byChangingLocked(amount)
            return voting
        }

        static func buildBlock(_ trackId: TrackIdLocal) -> TrackVoting {
            TrackVoting(
                trackId: trackId,
                locked: 0,
                votes: [:],
                prior: .notExisting,
                delegating: nil
            )
        }
    }

    static func track(@TrackVotingBuilder _ content: () -> TrackVoting) -> TrackVoting {
        content()
    }
}
