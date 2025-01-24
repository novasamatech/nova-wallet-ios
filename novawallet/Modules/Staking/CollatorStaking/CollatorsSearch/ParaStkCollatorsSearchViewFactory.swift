import Foundation
import SoraFoundation

struct ParaStkCollatorsSearchViewFactory {
    static func createParachainStakingView(
        for state: ParachainStakingSharedStateProtocol,
        collators: [CollatorStakingSelectionInfoProtocol],
        delegate: ParaStkSelectCollatorsDelegate
    ) -> ParaStkCollatorsSearchViewProtocol? {
        createView(
            for: ParaStkCollatorsSearchWireframe(sharedState: state),
            chainAsset: state.stakingOption.chainAsset,
            collators: collators,
            delegate: delegate
        )
    }

    static func createMythosStakingView(
        for state: MythosStakingSharedStateProtocol,
        collators: [CollatorStakingSelectionInfoProtocol],
        delegate: ParaStkSelectCollatorsDelegate
    ) -> ParaStkCollatorsSearchViewProtocol? {
        createView(
            for: MythosCollatorsSearchWireframe(sharedState: state),
            chainAsset: state.stakingOption.chainAsset,
            collators: collators,
            delegate: delegate
        )
    }

    static func createView(
        for wireframe: CollatorStakingSelectSearchWireframeProtocol,
        chainAsset: ChainAsset,
        collators: [CollatorStakingSelectionInfoProtocol],
        delegate: ParaStkSelectCollatorsDelegate
    ) -> ParaStkCollatorsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = ParaStkCollatorsSearchInteractor()

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
