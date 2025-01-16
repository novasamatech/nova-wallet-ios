import Foundation
import Foundation_iOS
import Keystore_iOS
import SubstrateSdk

final class StakingRewardDetailsViewFactory {
    static func createView(
        for state: RelaychainStakingSharedStateProtocol,
        input: StakingRewardDetailsInput
    ) -> StakingRewardDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset

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
            normalTimelefColor: R.color.colorTextPrimary()!
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
