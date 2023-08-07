import Foundation
import SoraFoundation

struct StakingTypeViewFactory {
    static func createView(chainAsset: ChainAsset, method _: StakingSelectionMethod) -> StakingTypeViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }
        let interactor = StakingTypeInteractor()
        let wireframe = StakingTypeWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = StakingTypeViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            countFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = StakingTypePresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = StakingTypeViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
