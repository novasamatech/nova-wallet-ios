import Foundation
import Foundation_iOS

struct CollatorStakingSelectSearchViewFactory {
    static func createParachainStakingView(
        for state: ParachainStakingSharedStateProtocol,
        collators: [CollatorStakingSelectionInfoProtocol],
        delegate: CollatorStakingSelectDelegate
    ) -> CollatorStakingSelectSearchViewProtocol? {
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
        delegate: CollatorStakingSelectDelegate
    ) -> CollatorStakingSelectSearchViewProtocol? {
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
        delegate: CollatorStakingSelectDelegate
    ) -> CollatorStakingSelectSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = CollatorStakingSelectSearchInteractor()

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = CollatorStakingSelectSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            collatorsInfo: collators,
            delegate: delegate,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = CollatorStakingSelectSearchViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
