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

        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = SwapSetupWireframe(assetListObservable: assetListObservable)
        let viewModelFactory = SwapsSetupViewModelFactory(
            balanceViewModelFactoryFacade: balanceViewModelFactoryFacade,
            networkViewModelFactory: NetworkViewModelFactory(),
            percentForamatter: NumberFormatter.percentSingle.localizableResource(),
            locale: LocalizationManager.shared.selectedLocale
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
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: LocalizationManager.shared,
            selectedAccount: selectedWallet,
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

    private static func createInteractor() -> SwapSetupInteractor? {
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

        let interactor = SwapSetupInteractor(
            xcmTransfersSyncService: xcmTransfersSyncService,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            assetConversionAggregatorFactory: assetConversionAggregator,
            assetConversionFeeService: feeService,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue
        )

        return interactor
    }
}
