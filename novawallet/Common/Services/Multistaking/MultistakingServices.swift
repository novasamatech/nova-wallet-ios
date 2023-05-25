import Foundation
import RobinHood

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

protocol OffchainMultistakingUpdateServiceProtocol: ApplicationServiceProtocol {
    func resolveAccountId(_ accountId: AccountId, chainAssetId: ChainAssetId)
}
