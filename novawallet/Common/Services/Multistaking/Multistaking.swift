import Foundation
import BigInt
import RobinHood

enum Multistaking {
    struct OffchainFilter: Hashable {
        let chainAsset: ChainAsset
        let stakingTypes: Set<StakingType>
        let accountId: AccountId

        func adding(newStakingTypes: Set<StakingType>) -> OffchainFilter {
            .init(
                chainAsset: chainAsset,
                stakingTypes: stakingTypes.union(newStakingTypes),
                accountId: accountId
            )
        }
    }

    struct OffchainFilters: Hashable {
        let stateFilters: [OffchainFilter]
        let rewardFilters: [OffchainFilter]

        func adding(newStateFilters: [OffchainFilter], newRewardFilters: [OffchainFilter]) -> OffchainFilters {
            .init(
                stateFilters: stateFilters + newStateFilters,
                rewardFilters: rewardFilters + newRewardFilters
            )
        }
    }

    struct OffchainRequest {
        let stateFilters: Set<OffchainFilter>
        let rewardFilters: Set<OffchainFilter>
    }

    enum OffchainStakingState: Hashable {
        case active
        case inactive
    }

    struct OffchainStaking: Hashable {
        let chainId: ChainModel.Id
        let stakingType: StakingType
        let maxApy: Decimal
        let state: OffchainStakingState
        let totalRewards: BigUInt?
    }

    typealias OffchainResponse = Set<OffchainStaking>
}

extension Set where Element == Multistaking.OffchainFilter {
    func groupByNetworkStaking() -> [Multistaking.Option: Multistaking.OffchainFilter] {
        reduce(into: [:]) { accumulator, filter in
            filter.stakingTypes.forEach { stakingType in
                let key = Multistaking.Option(chainAssetId: filter.chainAsset.chainAssetId, type: stakingType)
                accumulator[key] = filter
            }
        }
    }
}
