import Foundation
import Foundation_iOS

enum SubtensorValidatorInfoViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        target: SubtensorStakeTarget,
        hotkey: AccountId,
        detail: SubtensorValidatorDetail?
    ) -> ControllerBackedProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset
        let earnServices = state.earnServices

        let interactor = SubtensorValidatorInfoInteractor(
            target: target,
            hotkey: hotkey,
            chainAsset: chainAsset,
            directoryService: earnServices.validatorDirectoryService,
            yieldService: earnServices.yieldService,
            catalogueService: earnServices.catalogueService,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = SubtensorValidatorInfoPresenter(
            target: target,
            hotkey: hotkey,
            detail: detail,
            interactor: interactor,
            wireframe: SubtensorValidatorInfoWireframe(),
            viewModelFactory: SubtensorValidatorInfoViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: balanceViewModelFactory
            ),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = SubtensorValidatorInfoViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
