import Foundation
import Foundation_iOS
import Operation_iOS

struct SwapConfirmViewFactory {
    static func createView(
        initState: SwapConfirmInitState,
        flowState: SwapTokensFlowStateProtocol,
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

        let wireframe = SwapConfirmWireframe(flowState: flowState, completionClosure: completionClosure)

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let priceDiffModelFactory = SwapPriceDifferenceModelFactory(config: .defaultConfig)
        let percentFormatter = NumberFormatter.percentSingle.localizableResource()

        let viewModelFactory = SwapDetailsViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceAssetInfoFactory: priceAssetInfoFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            assetIconViewModelFactory: AssetIconViewModelFactory(),
            priceDifferenceModelFactory: priceDiffModelFactory,
            percentFormatter: percentFormatter
        )

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            percentFormatter: percentFormatter
        )

        let presenter = SwapConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            initState: initState,
            selectedWallet: wallet,
            viewModelFactory: viewModelFactory,
            priceDifferenceFactory: priceDiffModelFactory,
            priceStore: flowState.priceStore,
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
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        wallet: MetaAccountModel,
        initState: SwapConfirmInitState,
        flowState: SwapTokensFlowStateProtocol
    ) -> SwapConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetStorageFactory = AssetStorageInfoOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let interactor = SwapConfirmInteractor(
            state: flowState,
            initState: initState,
            chainRegistry: chainRegistry,
            assetStorageFactory: assetStorageFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            currencyManager: currencyManager,
            selectedWallet: wallet,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        return interactor
    }
}
