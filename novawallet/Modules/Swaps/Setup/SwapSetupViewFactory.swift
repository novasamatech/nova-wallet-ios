import Foundation
import SoraFoundation
import RobinHood

struct SwapSetupViewFactory {
    static func createView(
        assetListObservable: AssetListModelObservable,
        payChainAsset: ChainAsset,
        swapCompletionClosure: SwapCompletionClosure?
    ) -> SwapSetupViewProtocol? {
        createView(
            assetListObservable: assetListObservable,
            initState: .init(payChainAsset: payChainAsset),
            swapCompletionClosure: swapCompletionClosure
        )
    }

    static func createView(
        assetListObservable: AssetListModelObservable,
        initState: SwapSetupInitState,
        swapCompletionClosure: SwapCompletionClosure?
    ) -> SwapSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let balanceViewModelFactoryFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager))

        let generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManager(operationQueue: OperationManagerFacade.sharedDefaultQueue),
            logger: Logger.shared
        )

        let flowState = AssetConversionFlowFacade(
            wallet: selectedWallet,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            userStorageFacade: UserDataStorageFacade.shared,
            generalSubscriptonFactory: generalLocalSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        guard let interactor = createInteractor(for: flowState) else {
            return nil
        }

        let wireframe = SwapSetupWireframe(
            assetListObservable: assetListObservable,
            flowState: flowState,
            swapCompletionClosure: swapCompletionClosure
        )

        let issuesViewModelFactory = SwapIssueViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let viewModelFactory = SwapsSetupViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            issuesViewModelFactory: issuesViewModelFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            percentForamatter: NumberFormatter.percentSingle.localizableResource(),
            priceDifferenceConfig: .defaultConfig
        )

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let presenter = SwapSetupPresenter(
            initState: initState,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
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

    private static func createInteractor(for flowState: AssetConversionFlowFacadeProtocol) -> SwapSetupInteractor? {
        guard let currencyManager = CurrencyManager.shared,
              let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetConversionAggregator = AssetConversionAggregationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let assetStorageFactory = AssetStorageInfoOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let interactor = SwapSetupInteractor(
            flowState: flowState,
            assetConversionAggregatorFactory: assetConversionAggregator,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            assetStorageFactory: assetStorageFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            storageRepository: SubstrateRepositoryFactory().createChainStorageItemRepository(),
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue
        )

        return interactor
    }
}
