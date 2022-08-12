import Foundation
import SoraFoundation
import SoraKeystore

struct AnalyticsRewardDetailsViewFactory {
    static func createView(
        for state: StakingSharedState,
        rewardModel: AnalyticsRewardDetailsModel
    ) -> AnalyticsRewardDetailsViewProtocol? {
        guard let chainAsset = state.settings.value,
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = AnalyticsRewardDetailsInteractor()
        let wireframe = AnalyticsRewardDetailsWireframe()

        let assetInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = AnalyticsRewardDetailsViewModelFactory(
            assetInfo: assetInfo,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let presenter = AnalyticsRewardDetailsPresenter(
            rewardModel: rewardModel,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: chainAsset.chain
        )

        let view = AnalyticsRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
