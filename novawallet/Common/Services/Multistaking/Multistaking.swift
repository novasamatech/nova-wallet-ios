import Foundation
import BigInt
import RobinHood

enum Multistaking {
    struct OffchainFilter: Hashable {
        let chainAsset: ChainAsset
        let stakingTypes: Set<StakingType>
        let accountId: AccountId
    }

    struct OffchainRequest {
        let filters: Set<OffchainFilter>
    }

    struct OffchainActiveStaking: Hashable {
        let totalRewards: BigUInt
    }

    enum OffchainStakingState: Hashable {
        case active(OffchainActiveStaking)
        case inactive
    }

    struct OffchainStaking: Hashable {
        let chainId: ChainModel.Id
        let stakingType: StakingType
        let maxApy: Decimal
        let state: OffchainStakingState
    }

    typealias OffchainResponse = Set<OffchainStaking>
}

protocol MultistakingOffchainOperationFactoryProtocol {
    func createWrapper(
        for request: Multistaking.OffchainRequest
    ) -> CompoundOperationWrapper<Multistaking.OffchainResponse>
}

extension MultistakingOffchainOperationFactoryProtocol {
    func createWrapper(
        from wallet: MetaAccountModel,
        chainAssets: Set<ChainAsset>
    ) -> CompoundOperationWrapper<Multistaking.OffchainResponse> {
        let filters: [Multistaking.OffchainFilter] = chainAssets.compactMap { chainAsset in
            guard
                chainAsset.asset.hasStaking,
                let account = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
                return nil
            }

            let stakingTypes = (chainAsset.asset.stakings ?? []).filter { $0 != .unsupported }

            return Multistaking.OffchainFilter(
                chainAsset: chainAsset,
                stakingTypes: Set(stakingTypes),
                accountId: account.accountId
            )
        }

        let request = Multistaking.OffchainRequest(filters: Set(filters))

        return createWrapper(for: request)
    }
}
