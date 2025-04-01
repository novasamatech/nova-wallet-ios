import Foundation
import Operation_iOS
import SubstrateSdk
import Foundation_iOS

struct CollatorStakingSelectViewFactory {
    static func createView(
        for chainAsset: ChainAsset,
        delegate: CollatorStakingSelectDelegate,
        interactor: CollatorStakingSelectInteractor,
        wireframe: CollatorStakingSelectWireframeProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> CollatorStakingSelectViewProtocol? {
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let localizationManager = LocalizationManager.shared

        let presenter = CollatorStakingSelectPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = CollatorStakingSelectViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
