import Foundation

typealias AssetLocks = [AssetLock]

extension AssetLocks {
    func mainLocks() -> AssetLocks {
        LockType.locksOrder.compactMap { lockType in
            self.first(where: { lock in
                lock.lockType == lockType
            })
        }
    }

    func auxLocks() -> AssetLocks {
        compactMap { lock in
            guard lock.lockType != nil else {
                return lock
            }

            return nil
        }.sorted { lhs, rhs in
            lhs.amount > rhs.amount
        }
    }
}
