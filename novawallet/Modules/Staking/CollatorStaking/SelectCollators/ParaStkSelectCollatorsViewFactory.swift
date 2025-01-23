import Foundation
import SoraFoundation
import SubstrateSdk
import Operation_iOS

struct ParaStkSelectCollatorsViewFactory {
    static func createView(
        for chainAsset: ChainAsset,
        delegate: ParaStkSelectCollatorsDelegate,
        interactor: ParaStkSelectCollatorsInteractor,
        wireframe: CollatorStakingSelectWireframeProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> ParaStkSelectCollatorsViewProtocol? {
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let localizationManager = LocalizationManager.shared

        let presenter = ParaStkSelectCollatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkSelectCollatorsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
