import Foundation

struct MythosStakingFrozenBalance: Equatable {
    let staking: Balance
    let releasing: Balance
    let candidateBond: Balance

    init(staking: Balance, releasing: Balance, candidateBond: Balance) {
        self.staking = staking
        self.releasing = releasing
        self.candidateBond = candidateBond
    }

    init(locks: AssetLocks) {
        let balanceClosure: (String, AssetLocks) -> Balance = { type, locks in
            locks.reduce(Balance.zero) { total, lock in
                if
                    lock.module == MythosStakingPallet.freezeModule,
                    lock.type.toUTF8String() == type {
                    return total + lock.amount
                } else {
                    return total
                }
            }
        }

        staking = balanceClosure(MythosStakingPallet.stakingFreezeType, locks)
        releasing = balanceClosure(MythosStakingPallet.releasingFreezeType, locks)
        candidateBond = balanceClosure(MythosStakingPallet.candidacyBondFreezeType, locks)
    }

    var total: Balance {
        staking + releasing + candidateBond
    }
}
