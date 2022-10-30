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

        var isEmpty: Bool {
            amount == 0 && actions.isEmpty
        }

        static func emptyUnlock(at block: BlockNumber) -> Item {
            .init(amount: 0, unlockAt: block, actions: [])
        }
    }

    let items: [Item]

    func lockedBalance() -> BigUInt {
        items.reduce(BigUInt(0)) { $0 + $1.amount }
    }

    func availableUnlock(at block: BlockNumber) -> Item {
        items
            .filter { $0.unlockAt <= block }
            .reduce(Item.emptyUnlock(at: block)) { (accum, unlock) in
                Item(
                    amount: accum.amount + unlock.amount,
                    unlockAt: block,
                    actions: accum.actions.union(unlock.actions)
                )
            }
    }

    func remainingLocks(after block: BlockNumber) -> [Item] {
        items.filter { $0.unlockAt > block }
    }
}
