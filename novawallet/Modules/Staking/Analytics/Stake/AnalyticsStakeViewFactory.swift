import Foundation
import SoraKeystore
import SoraFoundation

struct AnalyticsStakeViewFactory {
    static func createView(for state: StakingSharedState) -> AnalyticsStakeViewProtocol? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let chainAsset = state.settings.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAddress = metaAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
        else {
            return nil
        }

        let interactor = AnalyticsStakeInteractor(
            selectedAccountAddress: selectedAddress,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            operationManager: OperationManagerFacade.sharedManager,
            currencyManager: currencyManager
        )

        let wireframe = AnalyticsStakeWireframe(state: state)

        let assetInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let viewModelFactory = AnalyticsStakeViewModelFactory(
            assetInfo: assetInfo,
            balanceViewModelFactory: balanceViewModelFactory,
            calendar: Calendar(identifier: .gregorian)
        )
        let presenter = AnalyticsStakePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = AnalyticsStakeViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
