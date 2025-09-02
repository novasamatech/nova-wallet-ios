import Foundation
import Foundation_iOS
import Operation_iOS

struct SwipeGovViewFactory {
    static func createView(sharedState: GovernanceSharedState) -> SwipeGovViewProtocol? {
        guard
            let option = sharedState.settings.value,
            let assetInfo = option.chain.utilityAssetDisplayInfo(),
            let currencyManager = CurrencyManager.shared,
            let summaryService = sharedState.swipeGovService,
            let connection = sharedState.chainRegistry.getConnection(for: option.chain.chainId),
            let runtimeProvider = sharedState.chainRegistry.getRuntimeProvider(for: option.chain.chainId),
            let interactor = createInteractor(for: sharedState)
        else {
            return nil
        }

        let wireframe = SwipeGovWireframe(sharedState: sharedState)

        let localizationManager = LocalizationManager.shared
        let viewModelFactory = SwipeGovViewModelFactory()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)

        let cardsViewModelFactory = VoteCardViewModelFactory(
            summaryFetchOperationFactory: summaryService,
            chain: option.chain,
            currencyManager: currencyManager,
            connection: connection,
            runtimeProvider: runtimeProvider,
            balanceViewModelFacade: balanceViewModelFacade,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            actionDetailsOperationFactory: sharedState.createActionsDetailsFactory(for: option),
            spendingAmountExtractor: sharedState.createReferendumSpendingExtractor(for: option)
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SwipeGovPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            cardsViewModelFactory: cardsViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            govBalanceCalculator: GovernanceBalanceCalculator(governanceType: option.type),
            utilityAssetInfo: assetInfo,
            localizationManager: localizationManager
        )

        let view = SwipeGovViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for state: GovernanceSharedState) -> SwipeGovInteractor? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let option = state.settings.value else {
            return nil
        }

        let votingBasketSubscriptionFactory = VotingBasketLocalSubscriptionFactory(
            chainRegistry: state.chainRegistry,
            storageFacade: UserDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let votingPowerSubscriptionFactory = VotingPowerLocalSubscriptionFactory(
            chainRegistry: state.chainRegistry,
            storageFacade: UserDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let repository = SwipeGovRepositoryFactory.createVotingItemsRepository(
            for: option.chain.chainId,
            metaId: metaAccount.metaId,
            using: UserDataStorageFacade.shared
        )

        return SwipeGovInteractor(
            metaAccount: metaAccount,
            governanceState: state,
            sorting: ReferendumsTimeSortingProvider(),
            basketItemsRepository: repository,
            votingBasketSubscriptionFactory: votingBasketSubscriptionFactory,
            votingPowerSubscriptionFactory: votingPowerSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
