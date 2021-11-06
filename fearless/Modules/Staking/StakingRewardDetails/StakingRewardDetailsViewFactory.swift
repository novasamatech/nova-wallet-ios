import Foundation
import SoraFoundation
import SoraKeystore
import SubstrateSdk

final class StakingRewardDetailsViewFactory {
    static func createView(
        for state: StakingSharedState,
        input: StakingRewardDetailsInput
    ) -> StakingRewardDetailsViewProtocol? {
        guard let chainAsset = state.settings.value else {
            return nil
        }

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let viewModelFactory = StakingRewardDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            iconGenerator: PolkadotIconGenerator(),
            chainFormat: chainAsset.chain.chainFormat
        )
        let presenter = StakingRewardDetailsPresenter(
            input: input,
            viewModelFactory: viewModelFactory,
            explorers: chainAsset.chain.explorers
        )
        let view = StakingRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let interactor = StakingRewardDetailsInteractor(
            asset: chainAsset.asset,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared
        )

        let wireframe = StakingRewardDetailsWireframe(state: state)

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
