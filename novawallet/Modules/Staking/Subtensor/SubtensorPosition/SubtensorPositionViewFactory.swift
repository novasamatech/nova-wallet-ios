import Foundation
import Foundation_iOS

enum SubtensorPositionViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        group: SubtensorPortfolioGroup
    ) -> SubtensorPositionViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let earnServices = state.earnServices

        let interactor = SubtensorPositionInteractor(
            state: state,
            netuid: group.netuid,
            catalogueService: earnServices.catalogueService,
            yieldService: earnServices.yieldService,
            subnetLogosProvider: earnServices.subnetLogosProvider,
            priceHistoryStore: SubtensorPriceHistoryStore(state: state, operationQueue: operationQueue),
            validatorFactory: SubtensorValidatorPresetFactory(
                directoryService: earnServices.validatorDirectoryService,
                recommendationService: earnServices.recommendationService,
                operationQueue: operationQueue,
                logger: Logger.shared
            ),
            rootHoldFactory: earnServices.rootHoldFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let presenter = SubtensorPositionPresenter(
            group: group,
            account: state.selectedAccount,
            chainAsset: state.stakingOption.chainAsset,
            pendingRootClaims: state.flowState.pendingRootClaims,
            interactor: interactor,
            wireframe: SubtensorPositionWireframe(state: state),
            viewModelFactory: SubtensorPositionViewModelFactory(
                chainAsset: state.stakingOption.chainAsset,
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
            ),
            localizationManager: LocalizationManager.shared
        )

        let singleTapHapticPlayer = HapticPlayerFactory.createHapticPlayer(patternConfiguration: .singleTap)

        let view = SubtensorPositionViewController(
            presenter: presenter,
            isRoot: group.netuid == SubtensorStakingPallet.rootNetuid,
            seekHapticPlayer: HapticPlayerFactory.createProgressivePlayer(patternConfiguration: .chartSeek),
            chartLongPressHapticPlayer: singleTapHapticPlayer,
            periodControlHapticPlayer: singleTapHapticPlayer,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter
        presenter.view = view

        return view
    }
}
