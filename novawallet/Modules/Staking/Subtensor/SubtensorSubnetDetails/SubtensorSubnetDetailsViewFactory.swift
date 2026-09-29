import Foundation
import Foundation_iOS

enum SubtensorSubnetDetailsViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        input: SubtensorSubnetDetailsInput,
        host: SubtensorSubnetDetailsHost,
        delegate: SubtensorSubnetSelectDelegate
    ) -> SubtensorSubnetDetailsViewProtocol? {
        guard
            !input.target.isRoot,
            input.target.netuid == input.subnet.netuid,
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = createInteractor(for: state, input: input, currencyManager: currencyManager)

        let viewModelFactory = SubtensorSubnetDetailsViewModelFactory(
            subnet: input.subnet,
            chainAsset: state.stakingOption.chainAsset,
            currency: currencyManager.selectedCurrency,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let presenter = SubtensorSubnetDetailsPresenter(
            input: input,
            host: host,
            selectionDelegate: delegate,
            interactor: interactor,
            wireframe: SubtensorSubnetDetailsWireframe(state: state),
            viewModelFactory: viewModelFactory,
            earnSettings: state.earnServices.earnSettings,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = SubtensorSubnetDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

private extension SubtensorSubnetDetailsViewFactory {
    static func createInteractor(
        for state: SubtensorStakingSharedStateProtocol,
        input: SubtensorSubnetDetailsInput,
        currencyManager: CurrencyManagerProtocol
    ) -> SubtensorSubnetDetailsInteractor {
        let earnServices = state.earnServices
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let presetFactory = SubtensorValidatorPresetFactory(
            directoryService: earnServices.validatorDirectoryService,
            recommendationService: earnServices.recommendationService,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        return SubtensorSubnetDetailsInteractor(
            subnet: input.subnet.ref,
            chainAsset: state.stakingOption.chainAsset,
            accountId: state.selectedAccount?.chainAccount.accountId,
            priceHistoryService: earnServices.priceHistoryService,
            rankingViewService: earnServices.rankingViewService,
            presetFactory: presetFactory,
            yieldService: earnServices.yieldService,
            earnConfigProvider: earnServices.earnConfigProvider,
            positionsSyncService: state.positionsSyncService,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}
