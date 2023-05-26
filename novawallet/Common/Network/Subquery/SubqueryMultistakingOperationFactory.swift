import Foundation
import RobinHood
import BigInt

final class SubqueryMultistakingOperationFactory: SubqueryBaseOperationFactory {
    private func buildAccountFilter(for request: Multistaking.OffchainRequest) throws -> String {
        let filterItems: [SubqueryFilter] = try request.filters.map { nextFilter in
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

        let resultFilter = SubqueryCompoundFilter.or(filterItems)

        return SubqueryFilterBuilder.buildBlock(resultFilter)
    }

    private func buildQuery(for request: Multistaking.OffchainRequest) throws -> String {
        let accountFilter = try buildAccountFilter(for: request)

        return """
           {
            activeStakers(
               \(accountFilter)
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

            accumulatedRewards(
                \(accountFilter)
            ) {
                nodes {
                    networkId
                    stakingType
                    amount
                }
            }
           }
        """
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

                let rewards: [SubqueryMultistaking.NetworkStaking: BigUInt]

                rewards = result.accumulatedRewards.nodes.reduce(into: [:]) {
                    $0[.init(networkId: $1.networkId, stakingType: $1.stakingType)] = $1.amount
                }

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

                    return Multistaking.OffchainStaking(
                        chainId: node.networkId.withoutHexPrefix(),
                        stakingType: StakingType(rawType: node.stakingType),
                        maxApy: node.maxApy,
                        state: state,
                        totalRewards: rewards[networkStaking]
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
