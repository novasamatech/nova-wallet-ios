import Foundation
import BigInt

struct GovernanceUnlockSchedule: Equatable {
    enum Action: Equatable, Hashable {
        case unvote(track: TrackIdLocal, index: ReferendumIdLocal)
        case unlock(track: TrackIdLocal)
    }

    enum ClaimTime: Equatable, Hashable {
        /// use 0 to mark the lock is available to unlock now
        case unlockAt(BlockNumber)
        case afterUndelegate

        var unlockAtBlock: BlockNumber? {
            switch self {
            case let .unlockAt(blockNumber):
                return blockNumber
            case .afterUndelegate:
                return nil
            }
        }

        func isAfter(time: ClaimTime) -> Bool {
            if let block1 = unlockAtBlock, let block2 = time.unlockAtBlock {
                return block1 > block2
            } else if unlockAtBlock == nil, time.unlockAtBlock == nil {
                return false
            } else if unlockAtBlock == nil {
                return true
            } else {
                return false
            }
        }
    }

    struct Item: Equatable {
        let amount: BigUInt

        let unlockWhen: ClaimTime

        let actions: Set<Action>

        var isEmpty: Bool {
            switch unlockWhen {
            case .unlockAt:
                return amount == 0 && actions.isEmpty
            case .afterUndelegate:
                return false
            }
        }

        static func emptyUnlock(at block: BlockNumber) -> Item {
            .init(amount: 0, unlockWhen: .unlockAt(block), actions: [])
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
            .filter { item in
                switch item.unlockWhen {
                case let .unlockAt(unlockAtBlock):
                    return unlockAtBlock <= block
                case .afterUndelegate:
                    return false
                }
            }
            .reduce(Claimable.empty()) { accum, unlock in
                .init(
                    amount: accum.amount + unlock.amount,
                    actions: accum.actions.union(unlock.actions)
                )
            }
    }

    func remainingLocks(after block: BlockNumber) -> [Item] {
        items.filter { item in
            switch item.unlockWhen {
            case let .unlockAt(unlockAtBlock):
                return unlockAtBlock > block
            case .afterUndelegate:
                return true
            }
        }
    }
}
