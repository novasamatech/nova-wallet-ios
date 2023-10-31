import Foundation
import SoraFoundation
import RobinHood

struct SwapConfirmViewFactory {
    static func createView(
        initState: SwapConfirmInitState
    ) -> SwapConfirmViewProtocol? {
        let accountRequest = initState.chainAssetIn.chain.accountRequest()

        guard let currencyManager = CurrencyManager.shared,
              let wallet = SelectedWalletSettings.shared.value,
              let chainAccountResponse = wallet.fetchMetaChainAccount(for: accountRequest) else {
            return nil
        }
        guard let interactor = createInteractor(
            wallet: wallet,
            initState: initState
        ) else {
            return nil
        }
        let wireframe = SwapConfirmWireframe()

        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let viewModelFactory = SwapConfirmViewModelFactory(
            locale: LocalizationManager.shared.selectedLocale,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            networkViewModelFactory: NetworkViewModelFactory(),
            percentForamatter: NumberFormatter.percentSingle.localizableResource()
        )

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let presenter = SwapConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAccountResponse: chainAccountResponse,
            localizationManager: LocalizationManager.shared,
            dataValidatingFactory: dataValidatingFactory,
            initState: initState
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
        initState: SwapConfirmInitState
    ) -> SwapConfirmInteractor? {
        let chainId = initState.chainAssetIn.chain.chainId
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let accountRequest = initState.chainAssetIn.chain.accountRequest()

        guard let connection = chainRegistry.getConnection(for: chainId),
              let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
              let chainModel = chainRegistry.getChain(for: chainId),
              let currencyManager = CurrencyManager.shared,
              let selectedAccount = wallet.fetchMetaChainAccount(for: accountRequest) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetConversionOperationFactory = AssetHubSwapOperationFactory(
            chain: chainModel,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        ).createService(account: selectedAccount.chainAccount, chain: chainModel)

        let feeService = AssetHubFeeService(
            wallet: wallet,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        let interactor = SwapConfirmInteractor(
            initState: initState,
            assetConversionFeeService: feeService,
            assetConversionOperationFactory: assetConversionOperationFactory,
            assetConversionExtrinsicService: AssetHubExtrinsicService(chain: chainModel),
            runtimeService: runtimeService,
            extrinsicService: extrinsicService,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            currencyManager: currencyManager,
            selectedWallet: wallet,
            operationQueue: operationQueue,
            signer: signingWrapper
        )

        return interactor
    }
}
