import Foundation
import Foundation_iOS
import Operation_iOS

struct SwapSetupViewFactory {
    static func createView(
        state: SwapTokensFlowStateProtocol,
        payChainAsset: ChainAsset,
        swapCompletionClosure: SwapCompletionClosure?
    ) -> SwapSetupViewProtocol? {
        createView(
            state: state,
            initState: .init(payChainAsset: payChainAsset),
            swapCompletionClosure: swapCompletionClosure
        )
    }

    static func createView(
        state: SwapTokensFlowStateProtocol,
        initState: SwapSetupInitState,
        swapCompletionClosure: SwapCompletionClosure?
    ) -> SwapSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let priceInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceInfoFactory)

        guard let interactor = createInteractor(for: state) else { return nil }

        let wireframe = SwapSetupWireframe(
            state: state,
            swapCompletionClosure: swapCompletionClosure
        )

        let issuesViewModelFactory = SwapIssueViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let priceDiffModelFactory = SwapPriceDifferenceModelFactory(config: .defaultConfig)
        let percentFormatter = NumberFormatter.percentSingle.localizableResource()

        let viewModelFactory = SwapsSetupViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            priceAssetInfoFactory: priceInfoFactory,
            issuesViewModelFactory: issuesViewModelFactory,
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

        let presenter = SwapSetupPresenter(
            initState: initState,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            priceDiffModelFactory: priceDiffModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            priceStore: state.priceStore,
            localizationManager: LocalizationManager.shared,
            selectedWallet: selectedWallet,
            slippageConfig: .defaultConfig,
            logger: Logger.shared
        )

        let view = SwapSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.basePresenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(for flowState: SwapTokensFlowStateProtocol) -> SwapSetupInteractor? {
        guard let currencyManager = CurrencyManager.shared,
              let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetStorageFactory = AssetStorageInfoOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let interactor = SwapSetupInteractor(
            state: flowState,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            assetStorageFactory: assetStorageFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            storageRepository: SubstrateRepositoryFactory().createChainStorageItemRepository(),
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        return interactor
    }
}
