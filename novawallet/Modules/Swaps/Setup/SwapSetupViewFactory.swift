import Foundation
import SoraFoundation
import RobinHood

struct SwapSetupViewFactory {
    static func createView(assetListObservable: AssetListModelObservable) -> SwapSetupViewProtocol? {
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
        let westmintChainId = KnowChainId.westmint
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let connection = chainRegistry.getConnection(for: westmintChainId),
              let runtimeService = chainRegistry.getRuntimeProvider(for: westmintChainId),
              let chainModel = chainRegistry.getChain(for: westmintChainId),
              let currencyManager = CurrencyManager.shared,
              let selectedWallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetConversionOperationFactory = AssetHubSwapOperationFactory(
            chain: chainModel,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )

        let feeService = AssetHubFeeService(
            wallet: selectedWallet,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let interactor = SwapSetupInteractor(
            assetConversionOperationFactory: assetConversionOperationFactory,
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
