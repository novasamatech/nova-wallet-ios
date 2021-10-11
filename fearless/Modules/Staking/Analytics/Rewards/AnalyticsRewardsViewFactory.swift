import Foundation
import SoraKeystore
import SoraFoundation

struct AnalyticsRewardsViewFactory {
    static func createView(
        for state: StakingSharedState,
        accountIsNominator: Bool
    ) -> AnalyticsRewardsViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(state: state)
        else {
            return nil
        }

        let wireframe = AnalyticsRewardsWireframe(state: state)

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let viewModelFactory = AnalyticsRewardsViewModelFactory(
            assetInfo: assetInfo,
            balanceViewModelFactory: balanceViewModelFactory,
            calendar: Calendar(identifier: .gregorian)
        )

        let presenter = AnalyticsRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            accountIsNominator: accountIsNominator,
            logger: Logger.shared
        )

        let view = AnalyticsRewardsViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        state: StakingSharedState
    ) -> AnalyticsRewardsInteractor? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let chainAsset = state.settings.value,
            let selectedAddress = metaAccount.fetch(
                for: chainAsset.chain.accountRequest()
            )?.toAddress() else {
            return nil
        }

        let interactor = AnalyticsRewardsInteractor(
            selectedAccountAddress: selectedAddress,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        return interactor
    }
}
