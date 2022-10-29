import Foundation
import BigInt

struct GovernanceUnlockSchedule {
    enum Action: Equatable, Hashable {
        case unvote(track: TrackIdLocal, index: ReferendumIdLocal)
        case unlock(track: TrackIdLocal)
    }

    struct Item {
        let amount: BigUInt

        /// use 0 to mark the lock is available to unlock now
        let unlockAt: BlockNumber

        let actions: Set<Action>
    }

    let items: [Item]
}
