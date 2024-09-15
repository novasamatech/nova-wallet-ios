import Foundation
import SoraFoundation
import Operation_iOS

struct TinderGovViewFactory {
    static func createView(
        metaAccount: MetaAccountModel,
        sharedState: GovernanceSharedState
    ) -> TinderGovViewProtocol? {
        guard
            let option = sharedState.settings.value,
            let summaryApi = option.chain.externalApis?.referendumSummary()?.first?.url,
            let connection = sharedState.chainRegistry.getConnection(for: option.chain.chainId),
            let runtimeProvider = sharedState.chainRegistry.getRuntimeProvider(for: option.chain.chainId),
            let assetInfo = option.chain.utilityAsset()?.displayInfo,
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared

        let mapper = VotingBasketItemMapper()

        let filter = NSPredicate.votingBasketItems(
            for: option.chain.chainId,
            metaId: metaAccount.metaId
        )
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let wireframe = TinderGovWireframe(
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

        let interactor = TinderGovInteractor(
            metaAccount: metaAccount,
            governanceState: sharedState,
            sorting: ReferendumsTimeSortingProvider(),
            basketItemsRepository: AnyDataProviderRepository(repository),
            votingBasketSubscriptionFactory: votingBasketSubscriptionFactory,
            votingPowerSubscriptionFactory: votingPowerSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let localizationManager = LocalizationManager.shared
        let viewModelFactory = TinderGovViewModelFactory()

        let summaryFetchOperationFactory = OpenGovSummaryOperationFactory(
            url: summaryApi,
            chain: option.chain
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let cardsViewModelFactory = VoteCardViewModelFactory(
            summaryFetchOperationFactory: summaryFetchOperationFactory,
            chain: option.chain,
            currencyManager: currencyManager,
            connection: connection,
            runtimeProvider: runtimeProvider,
            balanceViewModelFactory: balanceViewModelFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            actionDetailsOperationFactory: sharedState.createActionsDetailsFactory(for: option)
        )

        let presenter = TinderGovPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            cardsViewModelFactory: cardsViewModelFactory,
            localizationManager: localizationManager
        )

        let view = TinderGovViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
