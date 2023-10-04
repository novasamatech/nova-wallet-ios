import Foundation
import SoraFoundation

enum SwapAssetsOperationViewFactory {
    static func createView(
        for stateObservable: AssetListModelObservable,
        chainAsset: ChainAsset? = nil,
        delegate: AssetsSearchDelegate
    ) -> AssetsSearchViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let viewModelFactory = SwapAssetListViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory,
            assetFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.signedPercent.localizableResource(),
            currencyManager: currencyManager
        )

        guard let presenter = createPresenter(
            stateObservable: stateObservable,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            delegate: delegate
        ) else {
            return nil
        }

        let title: LocalizableResource<String> = .init {
            R.string.localizable.swapsReceiveTokenSelectionTitle(
                preferredLanguages: $0.rLanguages
            )
        }

        let view = SwapAssetsOperationViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(events: [.viewDidAppear]),
            createViewClosure: { SwapAssetsOperationViewLayout() },
            localizableTitle: title,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }

    private static func createPresenter(
        stateObservable: AssetListModelObservable,
        viewModelFactory: AssetListAssetViewModelFactoryProtocol,
        chainAsset: ChainAsset?,
        delegate: AssetsSearchDelegate
    ) -> SwapAssetsOperationPresenter? {
        let westmintChainId = KnowChainId.westmint
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let connection = chainRegistry.getConnection(for: westmintChainId),
              let runtimeService = chainRegistry.getRuntimeProvider(for: westmintChainId),
              let chainModel = chainRegistry.getChain(for: westmintChainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let assetConversionOperationFactory = AssetHubSwapOperationFactory(
            chain: chainModel,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )

        let interactor = SwapAssetsOperationInteractor(
            stateObservable: stateObservable,
            chainAsset: chainAsset,
            assetConversionOperationFactory: assetConversionOperationFactory,
            logger: Logger.shared,
            operationQueue: operationQueue
        )

        let presenter = SwapAssetsOperationPresenter(
            delegate: delegate,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            wireframe: SwapAssetsOperationWireframe()
        )

        interactor.presenter = presenter

        return presenter
    }
}
