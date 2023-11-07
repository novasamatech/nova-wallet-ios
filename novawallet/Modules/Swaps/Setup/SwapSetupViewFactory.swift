import Foundation
import SoraFoundation
import RobinHood

struct SwapSetupViewFactory {
    static func createView(
        assetListObservable: AssetListModelObservable,
        payChainAsset: ChainAsset
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

        guard let interactor = createInteractor(with: generalLocalSubscriptionFactory) else {
            return nil
        }

        let wireframe = SwapSetupWireframe(
            assetListObservable: assetListObservable,
            state: generalLocalSubscriptionFactory
        )

        let viewModelFactory = SwapsSetupViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            networkViewModelFactory: NetworkViewModelFactory(),
            percentForamatter: NumberFormatter.percentSingle.localizableResource(),
            locale: LocalizationManager.shared.selectedLocale
        )

        let issuesViewModelFactory = SwapIssueViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let dataValidatingFactory = SwapDataValidatorFactory(
            presentable: wireframe,
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade
        )

        let presenter = SwapSetupPresenter(
            payChainAsset: payChainAsset,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            issuesViewModelFactory: issuesViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: LocalizationManager.shared,
            selectedWallet: selectedWallet,
            purchaseProvider: PurchaseAggregator.defaultAggregator(),
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

    private static func createInteractor(
        with generalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    ) -> SwapSetupInteractor? {
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

        let feeService = AssetHubFeeService(
            wallet: selectedWallet,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let xcmTransfersSyncService = XcmTransfersSyncService(
            remoteUrl: ApplicationConfig.shared.xcmTransfersURL,
            operationQueue: operationQueue
        )

        let assetStorageFactory = AssetStorageInfoOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let interactor = SwapSetupInteractor(
            xcmTransfersSyncService: xcmTransfersSyncService,
            assetConversionAggregatorFactory: assetConversionAggregator,
            assetConversionFeeService: feeService,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            assetStorageFactory: assetStorageFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            generalLocalSubscriptionFactory: generalSubscriptionFactory,
            storageRepository: SubstrateRepositoryFactory().createChainStorageItemRepository(),
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue
        )

        return interactor
    }
}
