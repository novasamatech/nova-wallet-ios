import Foundation
import BigInt

struct GovernanceUnlockSchedule: Equatable {
    enum Action: Equatable, Hashable {
        case unvote(track: TrackIdLocal, index: ReferendumIdLocal)
        case unlock(track: TrackIdLocal)
    }

    struct Item: Equatable {
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

    struct Claimable: Equatable {
        let amount: BigUInt
        let actions: Set<Action>

        var isEmpty: Bool {
            amount == 0 && actions.isEmpty
        }

        static func empty() -> Claimable {
            Claimable(amount: 0, actions: [])
        }
    }

    let items: [Item]

    func lockedBalance() -> BigUInt {
        items.reduce(BigUInt(0)) { $0 + $1.amount }
    }

    func availableUnlock(at block: BlockNumber) -> Claimable {
        items
            .filter { $0.unlockAt <= block }
            .reduce(Claimable.empty()) { accum, unlock in
                .init(
                    amount: accum.amount + unlock.amount,
                    actions: accum.actions.union(unlock.actions)
                )
            }
    }

    func remainingLocks(after block: BlockNumber) -> [Item] {
        items.filter { $0.unlockAt > block }
    }
}
