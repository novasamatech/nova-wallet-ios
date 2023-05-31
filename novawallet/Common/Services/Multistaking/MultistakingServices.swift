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
        resolvedAccounts: [Multistaking.Option: AccountId],
        chainAssets: Set<ChainAsset>
    ) -> CompoundOperationWrapper<Multistaking.OffchainResponse> {
        let filters: [Multistaking.OffchainFilter] = chainAssets.flatMap { chainAsset in
            guard
                chainAsset.asset.hasStaking,
                let account = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
                return [Multistaking.OffchainFilter]()
            }

            let stakingTypes = (chainAsset.asset.stakings ?? []).filter { $0 != .unsupported }

            let accountIds = stakingTypes.reduce(
                into: [AccountId: Multistaking.OffchainFilter]()
            ) { result, stakingType in
                let stakingOption = Multistaking.Option(
                    chainAssetId: chainAsset.chainAssetId,
                    type: stakingType
                )

                let accountId = resolvedAccounts[stakingOption] ?? account.accountId

                if let existingFilter = result[accountId] {
                    result[accountId] = existingFilter.adding(newStakingTypes: [stakingType])
                } else {
                    result[accountId] = Multistaking.OffchainFilter(
                        chainAsset: chainAsset,
                        stakingTypes: [stakingType],
                        accountId: accountId
                    )
                }
            }

            return Array(accountIds.values)
        }

        let request = Multistaking.OffchainRequest(filters: Set(filters))

        return createWrapper(for: request)
    }
}
