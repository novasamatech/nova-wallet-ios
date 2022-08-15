import Foundation
import SoraFoundation
import SoraKeystore
import SubstrateSdk

final class StakingRewardDetailsViewFactory {
    static func createView(
        for state: StakingSharedState,
        input: StakingRewardDetailsInput
    ) -> StakingRewardDetailsViewProtocol? {
        guard let chainAsset = state.settings.value,
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let assetInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = StakingRewardDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            chainFormat: chainAsset.chain.chainFormat
        )

        let localizationManager = LocalizationManager.shared

        let timeleftFactory = PayoutTimeViewModelFactory(
            timeFormatter: TotalTimeFormatter(),
            normalTimelefColor: R.color.colorWhite()!
        )

        let presenter = StakingRewardDetailsPresenter(
            input: input,
            viewModelFactory: viewModelFactory,
            timeleftFactory: timeleftFactory,
            chain: chainAsset.chain,
            localizationManager: localizationManager
        )
        let view = StakingRewardDetailsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        let interactor = StakingRewardDetailsInteractor(
            asset: chainAsset.asset,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager
        )

        let wireframe = StakingRewardDetailsWireframe(state: state)

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
