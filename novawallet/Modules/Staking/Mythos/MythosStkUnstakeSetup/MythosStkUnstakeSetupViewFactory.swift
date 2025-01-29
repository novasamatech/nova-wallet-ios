import Foundation
import SoraFoundation

struct MythosStkUnstakeSetupViewFactory {
    static func createView(
        for state: MythosStakingSharedStateProtocol
    ) -> MythosStkUnstakeSetupViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                chainAsset: chainAsset,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = MythosStkUnstakeSetupWireframe()

        let assetDisplayInfo = chainAsset.assetDisplayInfo

        let priceInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceInfoFactory
        )

        let dataValidatingFactory = MythosStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceInfoFactory
        )

        let presenter = MythosStkUnstakeSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            accountDetailsViewModelFactory: CollatorStakingAccountViewModelFactory(chainAsset: chainAsset),
            hintViewModelFactory: CollatorStakingHintsViewModelFactory(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = MythosStkUnstakeSetupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for _: MythosStakingSharedStateProtocol,
        chainAsset _: ChainAsset,
        currencyManager _: CurrencyManagerProtocol
    ) -> MythosStkUnstakeSetupInteractor? {
        nil
    }
}
