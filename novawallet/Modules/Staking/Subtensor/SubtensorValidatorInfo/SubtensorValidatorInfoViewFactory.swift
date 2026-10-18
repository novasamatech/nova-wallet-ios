import Foundation
import Foundation_iOS

enum SubtensorValidatorInfoViewFactory {
    static func createView(
        for state: SubtensorSharedStateProtocol,
        target: SubtensorStakeTarget,
        hotkey: AccountId,
        detail: SubtensorValidatorDirectoryItem?,
        needsChainDetail: Bool
    ) -> ControllerBackedProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let chainAsset = state.stakingOption.chainAsset
        let earnServices = state.earnServices

        let interactor = SubtensorValidatorInfoInteractor(
            target: target,
            hotkey: hotkey,
            state: state,
            coverageOperationFactory: SubtensorValidatorCoverageOperationFactory(
                apiFactory: state.apiOperationFactory,
                catalogueOperationFactory: earnServices.catalogueOperationFactory,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            ),
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
            chain: chainAsset.chain,
            detail: detail,
            needsChainDetail: needsChainDetail,
            interactor: interactor,
            wireframe: SubtensorValidatorInfoWireframe(),
            viewModelFactory: SubtensorValidatorInfoViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: balanceViewModelFactory
            ),
            localizationManager: LocalizationManager.shared
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
