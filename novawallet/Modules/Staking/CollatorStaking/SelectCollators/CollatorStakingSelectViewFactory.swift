import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk

enum CollatorStakingSelectViewFactory {
    static func createView(
        for chainAsset: ChainAsset,
        delegate: CollatorStakingSelectDelegate,
        interactor: CollatorStakingSelectInteractor,
        wireframe: CollatorStakingSelectWireframeProtocol,
        currencyManager: CurrencyManagerProtocol,
        defaultSorting: CollatorsSortType = .rewards,
        statics: CollatorStakingDelegateStatics = .collator
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
            defaultSorting: defaultSorting,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = CollatorStakingSelectViewController(
            presenter: presenter,
            statics: statics,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
