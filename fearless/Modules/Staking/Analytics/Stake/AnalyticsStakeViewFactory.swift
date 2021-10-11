import Foundation
import SoraKeystore
import SoraFoundation

struct AnalyticsStakeViewFactory {
    static func createView(for state: StakingSharedState) -> AnalyticsStakeViewProtocol? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let chainAsset = state.settings.value,
            let selectedAddress = metaAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
        else {
            return nil
        }

        let interactor = AnalyticsStakeInteractor(
            selectedAccountAddress: selectedAddress,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let wireframe = AnalyticsStakeWireframe(state: state)

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)
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
