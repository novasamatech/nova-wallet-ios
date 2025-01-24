import Foundation

extension ParaStkCollatorInfoViewFactory {
    static func createMythosStakingView(
        for state: MythosStakingSharedStateProtocol,
        collatorInfo: CollatorStakingSelectionInfoProtocol
    ) -> ParaStkCollatorInfoViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let detailsSyncService = state.detailsSyncService else {
            return nil
        }

        let interactor = MythosCollatorInfoInteractor(
            chainAsset: chainAsset,
            stakingDetailsService: detailsSyncService,
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
