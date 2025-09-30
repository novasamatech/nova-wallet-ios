import Foundation
import BigInt

extension NominationPools {
    struct ActivePool {
        let poolId: PoolId
        let bondedAccountId: AccountId
        let validators: Set<AccountId>
    }

    struct ActivePools {
        let era: Staking.EraIndex
        let pools: [ActivePool]
    }

    struct PoolApy {
        let poolId: PoolId
        let bondedAccountId: AccountId
        let maxApy: Decimal
    }

    struct PoolStats {
        let poolId: PoolId
        let bondedAccountId: AccountId
        let membersCount: UInt32
        let maxApy: Decimal?
        let metadata: Data?
        let state: PoolState?
    }

    struct SelectedPool: Equatable {
        let poolId: PoolId
        let bondedAccountId: AccountId
        let metadata: Data?
        let maxApy: Decimal?

        var name: String? {
            metadata.flatMap { String(data: $0, encoding: .utf8) }
        }

        init(
            poolId: PoolId,
            bondedAccountId: AccountId,
            metadata: Data?,
            maxApy: Decimal?
        ) {
            self.poolId = poolId
            self.bondedAccountId = bondedAccountId
            self.metadata = metadata
            self.maxApy = maxApy
        }

        init(poolStats: PoolStats) {
            poolId = poolStats.poolId
            bondedAccountId = poolStats.bondedAccountId
            metadata = poolStats.metadata
            maxApy = poolStats.maxApy
        }

        func bondedAddress(for chainFormat: ChainFormat) -> AccountAddress? {
            try? bondedAccountId.toAddress(using: chainFormat)
        }

        func title(for chainFormat: ChainFormat) -> String? {
            if let poolName = name, !poolName.isEmpty {
                return poolName
            } else {
                return bondedAddress(for: chainFormat)
            }
        }
    }
}
