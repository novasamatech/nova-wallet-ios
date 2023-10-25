import Foundation
import SoraFoundation
import RobinHood

struct SwapConfirmViewFactory {
    static func createView(
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        feeChainAsset: ChainAsset,
        slippage: BigRational,
        quote: AssetConversion.Quote,
        quoteArgs: AssetConversion.QuoteArgs
    ) -> SwapConfirmViewProtocol? {
        let accountRequest = payChainAsset.chain.accountRequest()

        guard let currencyManager = CurrencyManager.shared,
              let selectedAccount = SelectedWalletSettings.shared.value,
              let chainAccountResponse = selectedAccount.fetchMetaChainAccount(for: accountRequest) else {
            return nil
        }
        guard let interactor = createInteractor(
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            feeChainAsset: feeChainAsset,
            slippage: slippage,
            quote: quote
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

        let presenter = SwapConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAssetIn: payChainAsset,
            chainAssetOut: receiveChainAsset,
            feeChainAsset: feeChainAsset,
            quote: quote,
            quoteArgs: quoteArgs,
            slippage: slippage,
            chainAccountResponse: chainAccountResponse
        )

        let view = SwapConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        payChainAsset: ChainAsset,
        receiveChainAsset: ChainAsset,
        feeChainAsset: ChainAsset,
        slippage: BigRational,
        quote: AssetConversion.Quote
    ) -> SwapConfirmInteractor? {
        let westmintChainId = KnowChainId.westmint
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let connection = chainRegistry.getConnection(for: westmintChainId),
              let runtimeService = chainRegistry.getRuntimeProvider(for: westmintChainId),
              let chainModel = chainRegistry.getChain(for: westmintChainId),
              let currencyManager = CurrencyManager.shared,
              let selectedAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetConversionOperationFactory = AssetHubSwapOperationFactory(
            chain: chainModel,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )
        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let interactor = SwapConfirmInteractor(
            payChainAsset: payChainAsset,
            receiveChainAsset: receiveChainAsset,
            feeChainAsset: feeChainAsset,
            slippage: slippage,
            quote: quote,
            assetConversionOperationFactory: assetConversionOperationFactory,
            assetConversionExtrinsicService: AssetHubExtrinsicService(chain: chainModel),
            runtimeService: runtimeService,
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicServiceFactory: extrinsicServiceFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            currencyManager: currencyManager,
            selectedAccount: selectedAccount,
            operationQueue: operationQueue
        )

        return interactor
    }
}
