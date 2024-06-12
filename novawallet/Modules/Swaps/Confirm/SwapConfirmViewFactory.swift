import Foundation
import SoraFoundation
import Operation_iOS

struct SwapConfirmViewFactory {
    static func createView(
        initState: SwapConfirmInitState,
        flowState: AssetConversionFlowFacadeProtocol,
        completionClosure: SwapCompletionClosure?
    ) -> SwapConfirmViewProtocol? {
        guard let currencyManager = CurrencyManager.shared, let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        guard let interactor = createInteractor(
            wallet: wallet,
            initState: initState,
            flowState: flowState
        ) else {
            return nil
        }

        let wireframe = SwapConfirmWireframe(completionClosure: completionClosure)

        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let viewModelFactory = SwapConfirmViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            networkViewModelFactory: NetworkViewModelFactory(),
            percentForamatter: NumberFormatter.percentSingle.localizableResource(),
            priceDifferenceConfig: .defaultConfig
        )

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let presenter = SwapConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            initState: initState,
            selectedWallet: wallet,
            viewModelFactory: viewModelFactory,
            slippageBounds: .init(config: SlippageConfig.defaultConfig),
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = SwapConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.basePresenter = presenter

        return view
    }

    private static func createInteractor(
        wallet: MetaAccountModel,
        initState: SwapConfirmInitState,
        flowState: AssetConversionFlowFacadeProtocol
    ) -> SwapConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let accountRequest = initState.chainAssetIn.chain.accountRequest()

        let chain = initState.chainAssetIn.chain

        guard let connection = chainRegistry.getConnection(for: chain.chainId),
              let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
              let currencyManager = CurrencyManager.shared,
              let selectedAccount = wallet.fetchMetaChainAccount(for: accountRequest) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetConversionAggregator = AssetConversionAggregationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue),
            userStorageFacade: UserDataStorageFacade.shared
        )

        guard let extrinsicService = try? flowState.createExtrinsicService(for: chain) else {
            return nil
        }

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        let assetStorageFactory = AssetStorageInfoOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let transactionStorage = SubstrateRepositoryFactory().createTxRepository()
        let persistExtrinsicService = PersistentExtrinsicService(
            repository: transactionStorage,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let interactor = SwapConfirmInteractor(
            flowState: flowState,
            initState: initState,
            assetConversionAggregator: assetConversionAggregator,
            assetConversionExtrinsicService: extrinsicService,
            chainRegistry: chainRegistry,
            assetStorageFactory: assetStorageFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            persistExtrinsicService: persistExtrinsicService,
            eventCenter: EventCenter.shared,
            currencyManager: currencyManager,
            selectedWallet: wallet,
            operationQueue: operationQueue,
            signer: signingWrapper,
            callPathFactory: AssetHubCallPathFactory()
        )

        return interactor
    }
}
