import Foundation
import Operation_iOS

protocol MultistakingOffchainOperationFactoryProtocol {
    func createWrapper(
        for request: Multistaking.OffchainRequest
    ) -> CompoundOperationWrapper<Multistaking.OffchainResponse>
}

extension MultistakingOffchainOperationFactoryProtocol {
    private func resolveAccountId(
        from accounts: [Multistaking.Option: AccountId],
        option: Multistaking.Option,
        defaultAccountResponse: ChainAccountResponse
    ) -> AccountId? {
        switch option.type {
        case .relaychain, .auraRelaychain, .azero, .parachain, .turing, .mythos, .unsupported:
            return accounts[option] ?? defaultAccountResponse.accountId
        case .nominationPools:
            // we don't want to use default account as it might be connected to direct staking
            return accounts[option]
        }
    }

    private func createWrapperFilters(
        for accounts: [Multistaking.Option: AccountId],
        chainAsset: ChainAsset,
        defaultAccountResponse: ChainAccountResponse
    ) -> [Multistaking.OffchainFilter] {
        let stakingTypes = chainAsset.asset.supportedStakings ?? []

        let filters = stakingTypes.reduce(into: [AccountId: Multistaking.OffchainFilter]()) { result, stakingType in
            let stakingOption = Multistaking.Option(chainAssetId: chainAsset.chainAssetId, type: stakingType)

            guard
                let accountId = resolveAccountId(
                    from: accounts,
                    option: stakingOption,
                    defaultAccountResponse: defaultAccountResponse
                ) else {
                return
            }

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

        return Array(filters.values)
    }

    func createWrapper(
        from wallet: MetaAccountModel,
        bondedAccounts: [Multistaking.Option: AccountId],
        rewardAccounts: [Multistaking.Option: AccountId],
        chainAssets: Set<ChainAsset>
    ) -> CompoundOperationWrapper<Multistaking.OffchainResponse> {
        let filters: Multistaking.OffchainFilters = chainAssets.reduce(
            Multistaking.OffchainFilters(stateFilters: [], rewardFilters: [])
        ) { result, chainAsset in
            guard
                chainAsset.asset.hasStaking,
                let account = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
                return result
            }

            let stateFilters = createWrapperFilters(
                for: bondedAccounts,
                chainAsset: chainAsset,
                defaultAccountResponse: account
            )

            let rewardFilters = createWrapperFilters(
                for: rewardAccounts,
                chainAsset: chainAsset,
                defaultAccountResponse: account
            )

            return result.adding(newStateFilters: stateFilters, newRewardFilters: rewardFilters)
        }

        let request = Multistaking.OffchainRequest(
            stateFilters: Set(filters.stateFilters),
            rewardFilters: Set(filters.rewardFilters)
        )

        return createWrapper(for: request)
    }
}
