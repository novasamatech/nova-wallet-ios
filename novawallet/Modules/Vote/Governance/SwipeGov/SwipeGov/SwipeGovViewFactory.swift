import Foundation
import SoraFoundation
import Operation_iOS

struct SwipeGovViewFactory {
    static func createView(
        metaAccount: MetaAccountModel,
        sharedState: GovernanceSharedState
    ) -> SwipeGovViewProtocol? {
        guard
            let option = sharedState.settings.value,
            let summaryApi = option.chain.externalApis?.referendumSummary()?.first?.url,
            let connection = sharedState.chainRegistry.getConnection(for: option.chain.chainId),
            let runtimeProvider = sharedState.chainRegistry.getRuntimeProvider(for: option.chain.chainId),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared

        let wireframe = SwipeGovWireframe(
            sharedState: sharedState,
            metaAccount: metaAccount
        )

        let votingBasketSubscriptionFactory = VotingBasketLocalSubscriptionFactory(
            chainRegistry: sharedState.chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let votingPowerSubscriptionFactory = VotingPowerLocalSubscriptionFactory(
            chainRegistry: sharedState.chainRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let repository = SwipeGovRepositoryFactory.createVotingItemsRepository(
            for: option.chain.chainId,
            metaId: metaAccount.metaId,
            using: storageFacade
        )

        let interactor = SwipeGovInteractor(
            metaAccount: metaAccount,
            governanceState: sharedState,
            sorting: ReferendumsTimeSortingProvider(),
            basketItemsRepository: repository,
            votingBasketSubscriptionFactory: votingBasketSubscriptionFactory,
            votingPowerSubscriptionFactory: votingPowerSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let localizationManager = LocalizationManager.shared
        let viewModelFactory = SwipeGovViewModelFactory()

        let summaryFetchOperationFactory = OpenGovSummaryOperationFactory(
            url: summaryApi,
            chain: option.chain
        )

        let balanceViewModelFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let cardsViewModelFactory = VoteCardViewModelFactory(
            summaryFetchOperationFactory: summaryFetchOperationFactory,
            chain: option.chain,
            currencyManager: currencyManager,
            connection: connection,
            runtimeProvider: runtimeProvider,
            balanceViewModelFacade: balanceViewModelFacade,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            actionDetailsOperationFactory: sharedState.createActionsDetailsFactory(for: option),
            spendingAmountExtractor: sharedState.createReferendumSpendingExtractor(for: option)
        )

        let presenter = SwipeGovPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            cardsViewModelFactory: cardsViewModelFactory,
            localizationManager: localizationManager
        )

        let view = SwipeGovViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
