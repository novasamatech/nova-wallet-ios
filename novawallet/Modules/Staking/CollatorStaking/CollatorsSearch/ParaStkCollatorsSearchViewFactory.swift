import Foundation
import SoraFoundation

struct ParaStkCollatorsSearchViewFactory {
    static func createView(
        for state: ParachainStakingSharedStateProtocol,
        collators: [CollatorStakingSelectionInfoProtocol],
        delegate: ParaStkSelectCollatorsDelegate
    ) -> ParaStkCollatorsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset

        let interactor = ParaStkCollatorsSearchInteractor()
        let wireframe = ParaStkCollatorsSearchWireframe(sharedState: state)

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = ParaStkCollatorsSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            collatorsInfo: collators,
            delegate: delegate,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkCollatorsSearchViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
