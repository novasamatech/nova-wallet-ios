import Foundation
import RobinHood
import BigInt

final class SubqueryMultistakingOperationFactory: SubqueryBaseOperationFactory {
    private func buildAccountFilter(for offchainFilters: Set<Multistaking.OffchainFilter>) throws -> SubqueryFilter {
        let filterItems: [SubqueryFilter] = try offchainFilters.map { nextFilter in
            let chain = nextFilter.chainAsset.chain
            let address: AccountAddress

            if chain.isEthereumBased {
                guard let ethAddress = nextFilter.accountId.toEthereumAddressWithChecksum() else {
                    throw CommonError.dataCorruption
                }

                address = ethAddress
            } else {
                address = try nextFilter.accountId.toAddress(using: chain.chainFormat)
            }

            let networkFilter = SubqueryEqualToFilter(
                fieldName: "networkId",
                value: chain.chainId.withHexPrefix()
            )

            let addressFilter = SubqueryEqualToFilter(
                fieldName: "address",
                value: address
            )

            let typeFilterItems = nextFilter.stakingTypes.map { stakingType in
                SubqueryEqualToFilter(fieldName: "stakingType", value: stakingType.rawValue)
            }

            let typeFilter = SubqueryCompoundFilter.or(typeFilterItems)

            return SubqueryCompoundFilter.and([networkFilter, addressFilter, typeFilter])
        }

        return SubqueryCompoundFilter.or(filterItems)
    }

    private func buildQuery(
        activeStakerQueryFilter: String,
        rewardsQueryFilter: String,
        slashesQueryFilter: String
    ) -> String {
        """
           {
            activeStakers(
               \(activeStakerQueryFilter)
            ) {
                nodes {
                    networkId
                    stakingType
                    address
                }
            }

            stakingApies {
                nodes {
                    networkId
                    stakingType
                    maxAPY
                }
            }

            rewards: rewards(
                \(rewardsQueryFilter)
            ) {
                groupedAggregates(groupBy: [NETWORK_ID,  STAKING_TYPE]) {
                    sum {
                        amount
                    }

                    keys
                }
            }

            slashes: rewards(
                \(slashesQueryFilter)
            ) {
                groupedAggregates(groupBy: [NETWORK_ID,  STAKING_TYPE]) {
                    sum {
                        amount
                    }

                    keys
                }
            }
           }
        """
    }

    private func buildQuery(for request: Multistaking.OffchainRequest) throws -> String {
        let activeStakersAccountFilter = try buildAccountFilter(for: request.stateFilters)
        let rewardsAccountFilter = try buildAccountFilter(for: request.rewardFilters)

        let activeStakerQueryFilter = SubqueryFilterBuilder.buildBlock(activeStakersAccountFilter)

        let rewardFilter = SubqueryEqualToFilter(fieldName: "type", value: SubqueryRewardType.reward)
        let rewardsQueryFilter = SubqueryFilterBuilder.buildBlock(
            SubqueryCompoundFilter.and([rewardsAccountFilter, rewardFilter])
        )

        let slashFilter = SubqueryEqualToFilter(fieldName: "type", value: SubqueryRewardType.slash)
        let slashesQueryFilter = SubqueryFilterBuilder.buildBlock(
            SubqueryCompoundFilter.and([rewardsAccountFilter, slashFilter])
        )

        return buildQuery(
            activeStakerQueryFilter: activeStakerQueryFilter,
            rewardsQueryFilter: rewardsQueryFilter,
            slashesQueryFilter: slashesQueryFilter
        )
    }
}

extension SubqueryMultistakingOperationFactory: MultistakingOffchainOperationFactoryProtocol {
    func createWrapper(
        for request: Multistaking.OffchainRequest
    ) -> CompoundOperationWrapper<Multistaking.OffchainResponse> {
        do {
            let query = try buildQuery(for: request)
            let operation = createOperation(for: query) { (result: SubqueryMultistaking.StatsResponse) in
                let activeStakers: [SubqueryMultistaking.NetworkStaking: AccountAddress]
                activeStakers = result.activeStakers.nodes.reduce(into: [:]) {
                    $0[.init(networkId: $1.networkId, stakingType: $1.stakingType)] = $1.address
                }

                let rewards = result.rewards.groupByNetworkStaking()
                let slashes = result.slashes.groupByNetworkStaking()

                let stakings = result.stakingApies.nodes.map { node in
                    let state: Multistaking.OffchainStakingState

                    let networkStaking = SubqueryMultistaking.NetworkStaking(
                        networkId: node.networkId,
                        stakingType: node.stakingType
                    )

                    if activeStakers[networkStaking] != nil {
                        state = .active
                    } else {
                        state = .inactive
                    }

                    let totalRewards: BigUInt?

                    if let reward = rewards[networkStaking] {
                        let slash = slashes[networkStaking] ?? 0

                        totalRewards = reward > slash ? reward - slash : 0
                    } else {
                        totalRewards = nil
                    }

                    return Multistaking.OffchainStaking(
                        chainId: node.networkId.withoutHexPrefix(),
                        stakingType: StakingType(rawType: node.stakingType),
                        maxApy: node.maxApy,
                        state: state,
                        totalRewards: totalRewards
                    )
                }

                return Set(stakings)
            }

            return CompoundOperationWrapper(targetOperation: operation)
        } catch {
            return .createWithError(error)
        }
    }
}

extension SubqueryAggregates where T == SubqueryMultistaking.AccumulatedReward {
    func groupByNetworkStaking() -> [SubqueryMultistaking.NetworkStaking: BigUInt] {
        groupedAggregates.reduce(into: [:]) {
            guard let networkId = $1.keys.first, let stakingType = $1.keys.last else {
                return
            }

            $0[.init(networkId: networkId, stakingType: stakingType)] = BigUInt(scientific: $1.sum.amount)
        }
    }
}
