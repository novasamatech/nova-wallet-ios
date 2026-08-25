import Foundation

extension CollatorStakingInfoViewFactory {
    static func createSubtensorStakingView(
        for state: SubtensorStakingSharedStateProtocol,
        delegateInfo: CollatorStakingSelectionInfoProtocol
    ) -> CollatorStakingInfoViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let positionsSyncService = state.positionsSyncService else {
            return nil
        }

        let interactor = SubtensorDelegateInfoInteractor(
            chainAsset: chainAsset,
            positionsSyncService: positionsSyncService,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager
        )

        return createView(
            for: interactor,
            chainAsset: chainAsset,
            collatorInfo: delegateInfo,
            currencyManager: currencyManager
        )
    }
}
