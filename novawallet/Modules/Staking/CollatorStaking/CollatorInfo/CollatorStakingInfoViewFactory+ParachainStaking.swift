import Foundation

extension CollatorStakingInfoViewFactory {
    static func createParachainStakingView(
        for state: ParachainStakingSharedStateProtocol,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    ) -> CollatorStakingInfoViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = metaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let interactor = ParaStkCollatorInfoInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager
        )

        return createView(
            for: interactor,
            chainAsset: chainAsset,
            collatorInfo: collatorInfo,
            currencyManager: currencyManager
        )
    }
}
