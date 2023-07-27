import Foundation

extension NominationPools {
    struct ActivePool {
        let poolId: PoolId
        let bondedAccountId: AccountId
        let validators: Set<AccountId>
    }

    struct PoolDetails {
        let poolId: PoolId
        let bondedAccountId: AccountId
        let bondedPool: BondedPool
        let metadata: Data?
    }

    struct ActivePools {
        let era: EraIndex
        let pools: [ActivePool]
    }
}
