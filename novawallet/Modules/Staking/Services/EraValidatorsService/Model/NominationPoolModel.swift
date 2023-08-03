import Foundation

extension NominationPools {
    struct ActivePool {
        let poolId: PoolId
        let bondedAccountId: AccountId
        let validators: Set<AccountId>
    }

    struct ActivePools {
        let era: EraIndex
        let pools: [ActivePool]
    }

    struct PoolStats {
        let poolId: PoolId
        let bondedAccountId: AccountId
        let membersCount: UInt32
        let maxApy: Decimal?
        let metadata: Data?
    }

    struct SelectedPool {
        let poolId: PoolId
        let bondedAccountId: AccountId
        let metadata: Data?

        init(poolStats: PoolStats) {
            poolId = poolStats.poolId
            bondedAccountId = poolStats.bondedAccountId
            metadata = poolStats.metadata
        }
    }
}
